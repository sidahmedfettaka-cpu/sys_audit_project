#!/bin/bash
# =============================================================================
# FILE        : config.sh
# DESCRIPTION : Global configuration variables for the audit system
# AUTHOR      : NSCS Students - Group Project
# DATE        : 2026
# =============================================================================

# --- Directory Paths ---
# Where all audit reports will be saved
REPORT_DIR="/var/log/sys_audit/reports"

# Where execution logs will be stored
LOG_DIR="/var/log/sys_audit/logs"

# --- Report Settings ---
# Hostname of this machine (used in report headers)
HOSTNAME_VAL=$(hostname)

# --- Email Settings ---
# Recipient email address for sending reports
EMAIL_RECIPIENT="admin@example.com"

# Sender name (shown in email)
EMAIL_SENDER="Audit System <no-reply@$(hostname)>"

# Subject line for emails
EMAIL_SUBJECT="System Audit Report - $(hostname) - $(date '+%Y-%m-%d')"

# SMTP configuration for msmtp (edit to match your email provider)
SMTP_HOST="smtp.gmail.com"
SMTP_PORT="587"
SMTP_USER="your_email@gmail.com"
SMTP_PASS="your_app_password"   # Use an App Password, NOT your real password

# --- Alert Settings ---
# CPU usage percentage above which an alert is triggered
CPU_ALERT_THRESHOLD=80

# SSH user for remote monitoring
REMOTE_USER="root"

# SSH target host (IP or hostname of remote machine)
REMOTE_HOST="192.168.1.100"

# SSH port (default is 22)
REMOTE_PORT="22"

# SSH key path (for key-based authentication - more secure than password)
SSH_KEY="$HOME/.ssh/id_rsa"

# --- Color Codes for Terminal Output ---
# These make the output easier to read in the terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'   # NC = No Color (resets formatting)
