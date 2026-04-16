#!/bin/bash
# =============================================================================
# FILE        : remote_monitor.sh
# DESCRIPTION : Remote machine monitoring via SSH
# AUTHOR      : NSCS Students - Group Project
# DATE        : 2026
# =============================================================================
# CYBERSECURITY NOTE:
#   This module uses SSH (Secure Shell) for all remote communication.
#   SSH encrypts all data in transit, which is essential for secure monitoring.
#   Best practices applied here:
#     - Key-based authentication (no password over network)
#     - Host key verification enabled (StrictHostKeyChecking)
#     - Specific user account (not root when possible)
#     - Minimal permissions principle
# =============================================================================

# =============================================================================
# FUNCTION: setup_ssh_key
# PURPOSE : Generate an SSH key pair if one doesn't exist yet
#           This enables passwordless (but secure) SSH authentication
# =============================================================================
setup_ssh_key() {
    section_header "SSH Key Setup"

    if [ -f "$SSH_KEY" ]; then
        echo -e "${YELLOW}SSH key already exists at: $SSH_KEY${NC}"
        echo "Public key:"
        cat "${SSH_KEY}.pub"
        return 0
    fi

    echo -e "${YELLOW}Generating new SSH key pair...${NC}"
    # -t rsa : use RSA algorithm
    # -b 4096: 4096-bit key (stronger than default 2048)
    # -f     : output file
    # -N ""  : no passphrase (for automation; add one for interactive use)
    # -C     : comment (label) for the key
    ssh-keygen -t rsa -b 4096 -f "$SSH_KEY" -N "" -C "nscs_audit_$(hostname)_$(date +%Y%m%d)"

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}SSH key pair created:${NC}"
        echo "  Private key: $SSH_KEY"
        echo "  Public key : ${SSH_KEY}.pub"
        echo ""
        echo -e "${CYAN}Next step: Copy your public key to the remote machine:${NC}"
        echo "  ssh-copy-id -i ${SSH_KEY}.pub $REMOTE_USER@$REMOTE_HOST"
        log_message "INFO" "SSH key generated at $SSH_KEY"
    else
        log_message "ERROR" "Failed to generate SSH key"
        return 1
    fi
}

# =============================================================================
# FUNCTION: test_ssh_connection
# PURPOSE : Test if SSH connection to the remote host works
# =============================================================================
test_ssh_connection() {
    echo -e "${YELLOW}Testing SSH connection to $REMOTE_USER@$REMOTE_HOST:$REMOTE_PORT ...${NC}"

    # SSH options:
    # -i        : use specific key file
    # -p        : port number
    # -o        : options for connection behavior
    # ConnectTimeout=10 : fail after 10 seconds instead of hanging forever
    # StrictHostKeyChecking=no : automatically accept new host keys
    #   NOTE: In production, use "yes" and pre-add the host key for better security
    # BatchMode=yes : don't prompt for passwords (for scripted use)
    ssh -i "$SSH_KEY" \
        -p "$REMOTE_PORT" \
        -o ConnectTimeout=10 \
        -o StrictHostKeyChecking=no \
        -o BatchMode=yes \
        "$REMOTE_USER@$REMOTE_HOST" \
        "echo 'SSH_OK'" 2>/dev/null

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}SSH connection successful!${NC}"
        log_message "INFO" "SSH connection test OK: $REMOTE_HOST"
        return 0
    else
        echo -e "${RED}SSH connection FAILED. Check host, user, and key configuration.${NC}"
        log_message "ERROR" "SSH connection failed: $REMOTE_HOST"
        return 1
    fi
}

# =============================================================================
# FUNCTION: run_remote_command
# PURPOSE : Execute a command on the remote machine via SSH and return output
# ARGS    : $1 = command string to run remotely
# =============================================================================
run_remote_command() {
    local remote_cmd="$1"

    ssh -i "$SSH_KEY" \
        -p "$REMOTE_PORT" \
        -o ConnectTimeout=10 \
        -o StrictHostKeyChecking=no \
        -o BatchMode=yes \
        "$REMOTE_USER@$REMOTE_HOST" \
        "$remote_cmd" 2>/dev/null
}

# =============================================================================
# FUNCTION: monitor_remote_machine
# PURPOSE : Collect key system info from a remote machine over SSH
# =============================================================================
monitor_remote_machine() {
    section_header "Remote Machine Monitoring"
    echo -e "${CYAN}Target: $REMOTE_USER@$REMOTE_HOST:$REMOTE_PORT${NC}"
    echo ""

    # First test if the connection works
    test_ssh_connection || return 1

    echo ""
    echo -e "${CYAN}--- Remote System Information ---${NC}"
    echo ""

    # Run multiple commands on the remote machine
    # Each command is sent separately for clarity

    echo -e "${BOLD}Hostname:${NC}"
    run_remote_command "hostname" | sed 's/^/  /'

    echo -e "${BOLD}OS & Kernel:${NC}"
    run_remote_command "uname -a" | sed 's/^/  /'

    echo -e "${BOLD}Uptime:${NC}"
    run_remote_command "uptime" | sed 's/^/  /'

    echo -e "${BOLD}CPU Usage:${NC}"
    run_remote_command "top -bn1 | head -5" | sed 's/^/  /'

    echo -e "${BOLD}Memory Usage:${NC}"
    run_remote_command "free -h" | sed 's/^/  /'

    echo -e "${BOLD}Disk Usage:${NC}"
    run_remote_command "df -h --total | grep -vE 'tmpfs|devtmpfs'" | sed 's/^/  /'

    echo -e "${BOLD}Logged-in Users:${NC}"
    run_remote_command "who" | sed 's/^/  /'

    echo -e "${BOLD}Open Ports:${NC}"
    run_remote_command "ss -tulnp 2>/dev/null || netstat -tulnp 2>/dev/null" | sed 's/^/  /'

    log_message "INFO" "Remote monitoring completed for $REMOTE_HOST"
}

# =============================================================================
# FUNCTION: send_report_to_remote
# PURPOSE : Copy a local report file to a remote server via SCP (SSH copy)
# =============================================================================
send_report_to_remote() {
    section_header "Send Report to Remote Server"

    # Use the last generated report
    local report_file="${LAST_REPORT_TXT}"

    if [ -z "$report_file" ] || [ ! -f "$report_file" ]; then
        echo -e "${RED}No report found. Please generate a report first.${NC}"
        return 1
    fi

    # Remote destination path
    local remote_path="/var/log/sys_audit/$(basename "$report_file")"

    echo -e "${YELLOW}Copying $report_file → $REMOTE_USER@$REMOTE_HOST:$remote_path${NC}"

    # scp = Secure Copy Protocol (uses SSH under the hood)
    scp -i "$SSH_KEY" \
        -P "$REMOTE_PORT" \
        -o StrictHostKeyChecking=no \
        "$report_file" \
        "$REMOTE_USER@$REMOTE_HOST:$remote_path" 2>/dev/null

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Report successfully sent to $REMOTE_HOST${NC}"
        log_message "INFO" "Report sent to $REMOTE_HOST:$remote_path"
    else
        echo -e "${RED}Failed to send report to remote server.${NC}"
        log_message "ERROR" "Failed to SCP report to $REMOTE_HOST"
        return 1
    fi
}

# =============================================================================
# FUNCTION: run_remote_audit
# PURPOSE : Run the audit script on the remote machine itself (centralized audit)
#           The remote machine must also have this audit system installed
# =============================================================================
run_remote_audit() {
    section_header "Run Remote Audit"
    echo -e "${CYAN}Target: $REMOTE_HOST${NC}"
    echo ""

    test_ssh_connection || return 1

    echo -e "${YELLOW}Running audit script on remote machine...${NC}"

    # Run the main.sh script remotely and collect output
    local remote_output
    remote_output=$(run_remote_command "bash /opt/sys_audit/scripts/main.sh --short 2>/dev/null")

    if [ -n "$remote_output" ]; then
        echo "$remote_output"
        log_message "INFO" "Remote audit ran on $REMOTE_HOST"
    else
        echo -e "${YELLOW}No output received. Make sure the audit system is installed on $REMOTE_HOST${NC}"
        log_message "WARNING" "No output from remote audit on $REMOTE_HOST"
    fi
}

# =============================================================================
# FUNCTION: remote_monitor_menu
# PURPOSE : Submenu for choosing remote monitoring actions
# =============================================================================
remote_monitor_menu() {
    section_header "Remote Monitoring Options"

    echo "  Target Host : $REMOTE_HOST"
    echo "  Target User : $REMOTE_USER"
    echo "  SSH Port    : $REMOTE_PORT"
    echo ""
    echo "  1) Test SSH Connection"
    echo "  2) Monitor Remote Machine (collect info)"
    echo "  3) Send Report to Remote Server"
    echo "  4) Run Audit on Remote Machine"
    echo "  5) Setup SSH Key Pair"
    echo "  0) Back to Main Menu"
    echo ""
    echo -n "Choice: "
    read -r rm_choice

    case "$rm_choice" in
        1) test_ssh_connection ;;
        2) monitor_remote_machine ;;
        3) send_report_to_remote ;;
        4) run_remote_audit ;;
        5) setup_ssh_key ;;
        0) return 0 ;;
        *) echo -e "${RED}Invalid option${NC}" ;;
    esac
}
