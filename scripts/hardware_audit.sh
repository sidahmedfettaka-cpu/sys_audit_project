#!/bin/bash
# =============================================================================
# FILE        : hardware_audit.sh
# DESCRIPTION : Collects detailed hardware information from the system
# AUTHOR      : Fettaka sidahmed
# DATE        : 2026
# =============================================================================
# This module gathers: CPU, GPU, RAM, Disk, Network, Motherboard, USB info
# All collected data is stored in global variables for use by the report module
# =============================================================================

# Global variables to store collected hardware data
HW_CPU=""
HW_CPU_CORES=""
HW_CPU_ARCH=""
HW_GPU=""
HW_RAM_TOTAL=""
HW_RAM_FREE=""
HW_RAM_USED=""
HW_DISK=""
HW_PARTITIONS=""
HW_NETWORK=""
HW_MAC_IP=""
HW_MOTHERBOARD=""
HW_USB=""

# =============================================================================
# FUNCTION: get_cpu_info
# PURPOSE : Retrieve CPU model, number of cores, and architecture
# =============================================================================
get_cpu_info() {
    # /proc/cpuinfo contains detailed CPU info on Linux
    HW_CPU=$(grep "model name" /proc/cpuinfo | head -1 | cut -d':' -f2 | sed 's/^ //')
    HW_CPU_CORES=$(nproc 2>/dev/null || grep -c "^processor" /proc/cpuinfo)
    HW_CPU_ARCH=$(uname -m)

    # If model name wasn't found, fall back to lscpu
    if [ -z "$HW_CPU" ] && check_command "lscpu"; then
        HW_CPU=$(lscpu | grep "Model name" | cut -d':' -f2 | sed 's/^ //')
    fi
}

# =============================================================================
# FUNCTION: get_gpu_info
# PURPOSE : Detect GPU (graphics card) if available
# =============================================================================
get_gpu_info() {
    HW_GPU="Not detected"

    # lspci lists all PCI devices; we filter for VGA/3D/Display (GPU keywords)
    if check_command "lspci"; then
        local gpu_raw
        gpu_raw=$(lspci 2>/dev/null | grep -iE "vga|3d|display")
        if [ -n "$gpu_raw" ]; then
            HW_GPU="$gpu_raw"
        fi
    fi

    # Alternatively, try glxinfo for more GPU details (optional, may not be installed)
    if [ "$HW_GPU" = "Not detected" ] && check_command "glxinfo"; then
        HW_GPU=$(glxinfo 2>/dev/null | grep "OpenGL renderer" | cut -d':' -f2 | sed 's/^ //')
    fi
}

# =============================================================================
# FUNCTION: get_ram_info
# PURPOSE : Get total, used, and free RAM from /proc/meminfo
# =============================================================================
get_ram_info() {
    # /proc/meminfo reports memory in kilobytes
    # We convert to MB (divide by 1024) for readability
    local total_kb
    local free_kb
    local available_kb

    total_kb=$(grep "MemTotal" /proc/meminfo | awk '{print $2}')
    free_kb=$(grep "MemFree" /proc/meminfo | awk '{print $2}')
    available_kb=$(grep "MemAvailable" /proc/meminfo | awk '{print $2}')

    # Convert KB to MB using integer math (bash doesn't do floats natively)
    HW_RAM_TOTAL=$(( total_kb / 1024 )) # Total installed RAM in MB
    HW_RAM_FREE=$(( available_kb / 1024 )) # Available (usable free) RAM in MB
    HW_RAM_USED=$(( (total_kb - available_kb) / 1024 )) # Used RAM in MB
}

# =============================================================================
# FUNCTION: get_disk_info
# PURPOSE : Collect disk sizes, filesystem types, partitions, and usage
# =============================================================================
get_disk_info() {
    # df shows disk usage per filesystem; -h = human readable, -T = filesystem type
    # We exclude tmpfs and devtmpfs (virtual filesystems, not real disks)
    HW_DISK=$(df -hT 2>/dev/null | grep -vE "^tmpfs|^devtmpfs|^udev|Filesystem")

    # lsblk shows block devices (disks and partitions) in a tree format
    if check_command "lsblk"; then
        HW_PARTITIONS=$(lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT 2>/dev/null)
    else
        HW_PARTITIONS="lsblk not available"
    fi
}

# =============================================================================
# FUNCTION: get_network_info
# PURPOSE : List all network interfaces with their IP and MAC addresses
# =============================================================================
get_network_info() {
    # ip command is the modern way to get network info (replaces ifconfig)
    if check_command "ip"; then
        HW_NETWORK=$(ip -brief address show 2>/dev/null)
        HW_MAC_IP=$(ip link show 2>/dev/null | awk '/^[0-9]+:/{iface=$2} /link\/ether/{print iface, "MAC:", $2}')

        # Add IP info next to MAC
        local ip_info
        ip_info=$(ip -4 addr show 2>/dev/null | awk '/^[0-9]+:/{iface=$2} /inet /{print iface, "IP:", $2}')
        HW_MAC_IP="$HW_MAC_IP
$ip_info"

    elif check_command "ifconfig"; then
        # Fallback to ifconfig if ip is not available
        HW_NETWORK=$(ifconfig 2>/dev/null)
        HW_MAC_IP="Use ifconfig output for MAC/IP details"
    else
        HW_NETWORK="Network tools not available"
        HW_MAC_IP="N/A"
    fi
}

# =============================================================================
# FUNCTION: get_motherboard_info
# PURPOSE : Get motherboard/system manufacturer and product info
# =============================================================================
get_motherboard_info() {
    HW_MOTHERBOARD="Not available (run as root for full info)"

    # dmidecode reads hardware info directly from BIOS/UEFI (requires root)
    if check_command "dmidecode" && [ "$EUID" -eq 0 ]; then
        local vendor product version
        vendor=$(dmidecode -s baseboard-manufacturer 2>/dev/null)
        product=$(dmidecode -s baseboard-product-name 2>/dev/null)
        version=$(dmidecode -s baseboard-version 2>/dev/null)
        HW_MOTHERBOARD="Vendor: ${vendor:-N/A} | Product: ${product:-N/A} | Version: ${version:-N/A}"
    elif [ -f "/sys/class/dmi/id/board_vendor" ]; then
        # Alternative: read directly from /sys filesystem (available without root)
        local vendor product
        vendor=$(cat /sys/class/dmi/id/board_vendor 2>/dev/null)
        product=$(cat /sys/class/dmi/id/board_name 2>/dev/null)
        HW_MOTHERBOARD="Vendor: ${vendor:-N/A} | Product: ${product:-N/A}"
    fi
}

# =============================================================================
# FUNCTION: get_usb_info
# PURPOSE : List all connected USB devices
# =============================================================================
get_usb_info() {
    HW_USB="No USB devices found or lsusb not available"

    # lsusb lists all USB devices connected to the system
    if check_command "lsusb"; then
        HW_USB=$(lsusb 2>/dev/null)
        if [ -z "$HW_USB" ]; then
            HW_USB="No USB devices detected"
        fi
    fi
}

# =============================================================================
# FUNCTION: collect_hardware_info
# PURPOSE : Run all hardware collection functions and display results
# =============================================================================
collect_hardware_info() {
    section_header "Hardware Audit - Collecting Information"
    log_message "INFO" "Starting hardware audit..."

    echo -e "${YELLOW}Gathering CPU info...${NC}"
    get_cpu_info

    echo -e "${YELLOW}Gathering GPU info...${NC}"
    get_gpu_info

    echo -e "${YELLOW}Gathering RAM info...${NC}"
    get_ram_info

    echo -e "${YELLOW}Gathering Disk info...${NC}"
    get_disk_info

    echo -e "${YELLOW}Gathering Network info...${NC}"
    get_network_info

    echo -e "${YELLOW}Gathering Motherboard info...${NC}"
    get_motherboard_info

    echo -e "${YELLOW}Gathering USB devices...${NC}"
    get_usb_info

    echo ""
    echo -e "${GREEN}Hardware audit complete!${NC}"
    log_message "INFO" "Hardware audit completed successfully"

    # Print a quick summary to the terminal
    section_header "Hardware Summary"
    print_info "CPU Model" "$HW_CPU"
    print_info "CPU Cores" "$HW_CPU_CORES"
    print_info "Architecture" "$HW_CPU_ARCH"
    print_info "RAM Total" "${HW_RAM_TOTAL} MB"
    print_info "RAM Used" "${HW_RAM_USED} MB"
    print_info "RAM Free" "${HW_RAM_FREE} MB"
    print_info "GPU" "$HW_GPU"
    print_info "Motherboard" "$HW_MOTHERBOARD"
}
