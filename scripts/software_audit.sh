#!/bin/bash
# =============================================================================
# FILE        : software_audit.sh
# DESCRIPTION : Collects OS and software information from the system
# AUTHOR      : NSCS Students - Group Project
# DATE        : 2026
# =============================================================================
# This module gathers: OS details, kernel, packages, users, services,
# processes, and open ports
# =============================================================================

# Global variables to store collected software data
SW_OS_NAME=""
SW_OS_VERSION=""
SW_KERNEL=""
SW_ARCH=""
SW_PACKAGES=""
SW_PACKAGE_COUNT=""
SW_LOGGED_USERS=""
SW_SERVICES=""
SW_PROCESSES=""
SW_OPEN_PORTS=""
SW_UPTIME=""
SW_SHELL=""

# =============================================================================
# FUNCTION: get_os_info
# PURPOSE : Get OS name, version, and kernel details
# =============================================================================
get_os_info() {
    # uname gives kernel info
    SW_KERNEL=$(uname -r)
    SW_ARCH=$(uname -m)

    # /etc/os-release is the standard way to get distro info on modern Linux
    if [ -f /etc/os-release ]; then
        # Source the file to get variables like NAME, VERSION, etc.
        # We use a subshell to avoid polluting global namespace
        SW_OS_NAME=$(grep "^NAME=" /etc/os-release | cut -d'=' -f2 | tr -d '"')
        SW_OS_VERSION=$(grep "^VERSION=" /etc/os-release | cut -d'=' -f2 | tr -d '"')

        # Some distros use VERSION_ID instead of VERSION
        if [ -z "$SW_OS_VERSION" ]; then
            SW_OS_VERSION=$(grep "^VERSION_ID=" /etc/os-release | cut -d'=' -f2 | tr -d '"')
        fi

    elif [ -f /etc/lsb-release ]; then
        # Older Ubuntu/Debian systems use lsb-release
        SW_OS_NAME=$(grep "DISTRIB_ID" /etc/lsb-release | cut -d'=' -f2)
        SW_OS_VERSION=$(grep "DISTRIB_RELEASE" /etc/lsb-release | cut -d'=' -f2)
    else
        SW_OS_NAME=$(uname -s)
        SW_OS_VERSION="Unknown"
    fi

    # Get system uptime
    SW_UPTIME=$(uptime -p 2>/dev/null || uptime)

    # Get current default shell
    SW_SHELL=$(basename "$SHELL")
}

# =============================================================================
# FUNCTION: get_installed_packages
# PURPOSE : List and count all installed software packages
# =============================================================================
get_installed_packages() {
    SW_PACKAGE_COUNT="Unknown"
    SW_PACKAGES="Package manager not detected"

    # Check which package manager is available (distro-dependent)
    if check_command "dpkg"; then
        # Debian/Ubuntu: dpkg --get-selections lists all installed packages
        SW_PACKAGE_COUNT=$(dpkg --get-selections 2>/dev/null | grep -c "install")
        # For the report, show the list (can be very long, so we'll limit to 50 in short report)
        SW_PACKAGES=$(dpkg --get-selections 2>/dev/null | grep "install" | awk '{print $1}')

    elif check_command "rpm"; then
        # Red Hat/CentOS/Fedora: rpm -qa lists all installed packages
        SW_PACKAGE_COUNT=$(rpm -qa 2>/dev/null | wc -l)
        SW_PACKAGES=$(rpm -qa 2>/dev/null)

    elif check_command "pacman"; then
        # Arch Linux: pacman -Q lists installed packages
        SW_PACKAGE_COUNT=$(pacman -Q 2>/dev/null | wc -l)
        SW_PACKAGES=$(pacman -Q 2>/dev/null)
    fi
}

# =============================================================================
# FUNCTION: get_logged_users
# PURPOSE : Show which users are currently logged into the system
# =============================================================================
get_logged_users() {
    # 'who' shows currently logged-in users with their login time and terminal
    SW_LOGGED_USERS=$(who 2>/dev/null)
    if [ -z "$SW_LOGGED_USERS" ]; then
        SW_LOGGED_USERS="No users currently logged in (or 'who' not available)"
    fi
}

# =============================================================================
# FUNCTION: get_running_services
# PURPOSE : List active (running) system services using systemd or init
# =============================================================================
get_running_services() {
    SW_SERVICES="Service info not available"

    # systemd is used by most modern Linux distributions
    if check_command "systemctl"; then
        # --no-pager prevents output from opening in a pager (like less)
        # state=running filters only active services
        SW_SERVICES=$(systemctl list-units --type=service --state=running \
                      --no-pager 2>/dev/null | grep ".service")

    elif check_command "service"; then
        # Fallback for older SysV init systems
        SW_SERVICES=$(service --status-all 2>/dev/null)
    fi
}

# =============================================================================
# FUNCTION: get_active_processes
# PURPOSE : Get the list of currently running processes
# =============================================================================
get_active_processes() {
    # ps aux shows all running processes with CPU and memory usage
    # We capture the top 20 by CPU usage for the report
    SW_PROCESSES=$(ps aux --sort=-%cpu 2>/dev/null | head -21)

    if [ -z "$SW_PROCESSES" ]; then
        SW_PROCESSES=$(ps -ef 2>/dev/null | head -21)
    fi
}

# =============================================================================
# FUNCTION: get_open_ports
# PURPOSE : Show all open/listening network ports and the programs using them
# =============================================================================
get_open_ports() {
    SW_OPEN_PORTS="Port scanning tools not available"

    # ss is the modern replacement for netstat
    if check_command "ss"; then
        # -t = TCP, -u = UDP, -l = listening, -n = numeric (no DNS lookup), -p = show process
        SW_OPEN_PORTS=$(ss -tulnp 2>/dev/null)

    elif check_command "netstat"; then
        # Fallback to netstat if ss is not available
        SW_OPEN_PORTS=$(netstat -tulnp 2>/dev/null)
    fi
}

# =============================================================================
# FUNCTION: collect_software_info
# PURPOSE : Run all software collection functions and display summary
# =============================================================================
collect_software_info() {
    section_header "Software Audit - Collecting Information"
    log_message "INFO" "Starting software audit..."

    echo -e "${YELLOW}Gathering OS info...${NC}"
    get_os_info

    echo -e "${YELLOW}Gathering installed packages...${NC}"
    get_installed_packages

    echo -e "${YELLOW}Gathering logged-in users...${NC}"
    get_logged_users

    echo -e "${YELLOW}Gathering running services...${NC}"
    get_running_services

    echo -e "${YELLOW}Gathering active processes...${NC}"
    get_active_processes

    echo -e "${YELLOW}Gathering open ports...${NC}"
    get_open_ports

    echo ""
    echo -e "${GREEN}Software audit complete!${NC}"
    log_message "INFO" "Software audit completed successfully"

    # Print a quick summary to the terminal
    section_header "Software Summary"
    print_info "OS Name" "$SW_OS_NAME"
    print_info "OS Version" "$SW_OS_VERSION"
    print_info "Kernel Version" "$SW_KERNEL"
    print_info "Architecture" "$SW_ARCH"
    print_info "Installed Packages" "$SW_PACKAGE_COUNT"
    print_info "System Uptime" "$SW_UPTIME"
    print_info "Default Shell" "$SW_SHELL"
}
