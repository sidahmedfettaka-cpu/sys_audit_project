#!/bin/bash
# =============================================================================
# FILE        : main.sh
# DESCRIPTION : Main entry point for the Linux Audit & Monitoring System
# AUTHOR      : NSCS Students - Group Project
# DATE        : 2026
# USAGE       : sudo bash main.sh [--short | --full | --menu]
# =============================================================================

# --- Source all modules ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/utils.sh"
source "$SCRIPT_DIR/hardware_audit.sh"
source "$SCRIPT_DIR/software_audit.sh"
source "$SCRIPT_DIR/report.sh"
source "$SCRIPT_DIR/email_send.sh"
source "$SCRIPT_DIR/remote_monitor.sh"

# =============================================================================
# FUNCTION: show_menu
# PURPOSE : Display an interactive menu for the user to choose actions
# =============================================================================
show_menu() {
    clear
    echo -e "${CYAN}============================================================${NC}"
    echo -e "${CYAN}   Linux System Audit & Monitoring Tool - NSCS 2025/2026   ${NC}"
    echo -e "${CYAN}============================================================${NC}"
    echo ""
    echo -e "${YELLOW}  Please choose an option:${NC}"
    echo ""
    echo "  1) Run Hardware Audit Only"
    echo "  2) Run Software Audit Only"
    echo "  3) Run Full Audit (Hardware + Software)"
    echo "  4) Generate Short Report"
    echo "  5) Generate Full Report"
    echo "  6) Send Report via Email"
    echo "  7) Remote Monitoring"
    echo "  8) Compare Two Reports"
    echo "  9) Check CPU Alert (threshold 80%)"
    echo "  0) Exit"
    echo ""
    echo -e "${CYAN}============================================================${NC}"
    echo -n "  Your choice: "
}

# =============================================================================
# FUNCTION: run_menu
# PURPOSE : Loop the interactive menu until the user exits
# =============================================================================
run_menu() {
    local choice
    while true; do
        show_menu
        read -r choice
        echo ""
        case "$choice" in
            1)
                log_message "INFO" "User selected: Hardware Audit"
                collect_hardware_info
                press_enter
                ;;
            2)
                log_message "INFO" "User selected: Software Audit"
                collect_software_info
                press_enter
                ;;
            3)
                log_message "INFO" "User selected: Full Audit"
                collect_hardware_info
                collect_software_info
                press_enter
                ;;
            4)
                log_message "INFO" "User selected: Generate Short Report"
                collect_hardware_info
                collect_software_info
                generate_report "short"
                press_enter
                ;;
            5)
                log_message "INFO" "User selected: Generate Full Report"
                collect_hardware_info
                collect_software_info
                generate_report "full"
                press_enter
                ;;
            6)
                log_message "INFO" "User selected: Send Email"
                send_report_email
                press_enter
                ;;
            7)
                log_message "INFO" "User selected: Remote Monitoring"
                remote_monitor_menu
                press_enter
                ;;
            8)
                log_message "INFO" "User selected: Compare Reports"
                compare_reports
                press_enter
                ;;
            9)
                log_message "INFO" "User selected: CPU Alert Check"
                check_cpu_alert
                press_enter
                ;;
            0)
                echo -e "${GREEN}Goodbye!${NC}"
                log_message "INFO" "User exited the menu"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option. Please try again.${NC}"
                sleep 1
                ;;
        esac
    done
}

# =============================================================================
# FUNCTION: press_enter
# PURPOSE : Wait for user to press Enter before going back to menu
# =============================================================================
press_enter() {
    echo ""
    echo -e "${YELLOW}Press [Enter] to return to the menu...${NC}"
    read -r
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

# Check if running as root (needed for some hardware info commands)
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${YELLOW}[WARNING] Some hardware info commands require root privileges.${NC}"
        echo -e "${YELLOW}          Consider running with: sudo bash main.sh${NC}"
        echo ""
        sleep 2
    fi
}

# Create required directories if they don't exist
init_directories() {
    mkdir -p "$REPORT_DIR" "$LOG_DIR"
    log_message "INFO" "Audit system started"
}

# --- Parse command-line arguments ---
case "$1" in
    --short)
        check_root
        init_directories
        collect_hardware_info
        collect_software_info
        generate_report "short"
        ;;
    --full)
        check_root
        init_directories
        collect_hardware_info
        collect_software_info
        generate_report "full"
        ;;
    --menu | "")
        check_root
        init_directories
        run_menu
        ;;
    --help)
        echo "Usage: sudo bash main.sh [OPTION]"
        echo ""
        echo "Options:"
        echo "  --short    Run full audit and generate a short (summary) report"
        echo "  --full     Run full audit and generate a detailed full report"
        echo "  --menu     Launch the interactive menu (default)"
        echo "  --help     Show this help message"
        ;;
    *)
        echo -e "${RED}Unknown option: $1${NC}"
        echo "Use --help for usage information."
        exit 1
        ;;
esac
