#!/bin/bash
# =============================================================================
# FILE        : setup_cron.sh
# DESCRIPTION : Configures automatic scheduled execution via cron jobs
# AUTHOR      : Fettaka Sidahmed
# DATE        : 2026
# USAGE       : sudo bash setup_cron.sh [--install | --remove | --show]
# =============================================================================
# What is cron?
#   cron is the standard Linux task scheduler. It runs commands automatically
#   at specified times/dates using a file called the "crontab".
#
# Crontab format:
#   ┌──── Minute   (0-59)
#   │ ┌─── Hour    (0-23)
#   │ │ ┌── Day    (1-31)
#   │ │ │ ┌─ Month (1-12)
#   │ │ │ │ ┌ Weekday (0-7, 0=Sunday)
#   │ │ │ │ │
#   * * * * *  command_to_run
#
# Example: "0 4 * * *" = run every day at 04:00 AM
# =============================================================================

# Get the real path to the scripts directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAIN_SCRIPT="$SCRIPT_DIR/main.sh"
LOG_DIR="/var/log/sys_audit/logs"
CRON_LOG="$LOG_DIR/cron_execution.log"

# Cron schedule: daily at 04:00 AM
CRON_SCHEDULE="0 4 * * *"

# The full cron job entry that will be added
# We redirect output to a log file so we can debug if something goes wrong
CRON_JOB="$CRON_SCHEDULE bash $MAIN_SCRIPT --full >> $CRON_LOG 2>&1"

# A unique comment tag so we can identify and remove our cron jobs later
CRON_TAG="# NSCS_AUDIT_SYSTEM"

# =============================================================================
# FUNCTION: install_cron
# PURPOSE : Add the audit cron job to root's crontab
# =============================================================================
install_cron() {
    echo ""
    echo "Installing cron job..."
    echo "Schedule: Every day at 04:00 AM"
    echo "Command : $MAIN_SCRIPT --full"
    echo "Log     : $CRON_LOG"
    echo ""

    # Create log directory if it doesn't exist
    mkdir -p "$LOG_DIR"

    # Check if cron job already exists (to avoid duplicates)
    if crontab -l 2>/dev/null | grep -q "$MAIN_SCRIPT"; then
        echo "Cron job already exists. Skipping."
        echo "Use --remove first if you want to change the schedule."
        return 1
    fi

    # Add the cron job:
    # 1. Get existing crontab (crontab -l)
    # 2. Add our new entry
    # 3. Write it back (crontab -)
    (
        crontab -l 2>/dev/null    # Print existing cron jobs (if any)
        echo "$CRON_TAG"          # Add our comment tag
        echo "$CRON_JOB"          # Add our new job
    ) | crontab -

    if [ $? -eq 0 ]; then
        echo "Cron job installed successfully!"
        echo ""
        echo "Current crontab:"
        crontab -l
    else
        echo "ERROR: Failed to install cron job."
        return 1
    fi
}

# =============================================================================
# FUNCTION: remove_cron
# PURPOSE : Remove the audit cron job from root's crontab
# =============================================================================
remove_cron() {
    echo "Removing NSCS Audit cron job..."

    # Check if our cron job exists
    if ! crontab -l 2>/dev/null | grep -q "$MAIN_SCRIPT"; then
        echo "No NSCS Audit cron job found."
        return 0
    fi

    # Remove lines containing our script path and our comment tag
    # grep -v = "invert match" (show lines that do NOT match)
    crontab -l 2>/dev/null | grep -v "$MAIN_SCRIPT" | grep -v "$CRON_TAG" | crontab -

    if [ $? -eq 0 ]; then
        echo "Cron job removed successfully."
    else
        echo "ERROR: Failed to remove cron job."
        return 1
    fi
}

# =============================================================================
# FUNCTION: show_cron
# PURPOSE : Display the current crontab and our specific job status
# =============================================================================
show_cron() {
    echo "=========================================="
    echo " Current Crontab for $(whoami):"
    echo "=========================================="
    crontab -l 2>/dev/null || echo "(empty crontab)"
    echo ""
    echo "=========================================="

    if crontab -l 2>/dev/null | grep -q "$MAIN_SCRIPT"; then
        echo " NSCS Audit cron job: INSTALLED"
    else
        echo " NSCS Audit cron job: NOT installed"
        echo " Run: sudo bash setup_cron.sh --install"
    fi
    echo "=========================================="
}

# =============================================================================
# FUNCTION: set_custom_schedule
# PURPOSE : Let the user enter a custom cron schedule
# =============================================================================
set_custom_schedule() {
    echo ""
    echo "Current schedule: $CRON_SCHEDULE (daily at 04:00 AM)"
    echo ""
    echo "Common schedules:"
    echo "  0 4  * * *   = Daily at 4:00 AM"
    echo "  0 */6 * * *  = Every 6 hours"
    echo "  0 0 * * 1    = Every Monday midnight"
    echo "  */30 * * * * = Every 30 minutes"
    echo ""
    echo -n "Enter new cron schedule (or press Enter to keep current): "
    read -r new_schedule

    if [ -n "$new_schedule" ]; then
        CRON_SCHEDULE="$new_schedule"
        CRON_JOB="$CRON_SCHEDULE bash $MAIN_SCRIPT --full >> $CRON_LOG 2>&1"
        echo "Schedule updated to: $CRON_SCHEDULE"
    fi
}

# =============================================================================
# MAIN: Parse command-line arguments
# =============================================================================
case "${1:---show}" in
    --install)
        install_cron
        ;;
    --remove)
        remove_cron
        ;;
    --show)
        show_cron
        ;;
    --custom)
        set_custom_schedule
        install_cron
        ;;
    --help)
        echo "Usage: sudo bash setup_cron.sh [OPTION]"
        echo ""
        echo "Options:"
        echo "  --install  Add the audit cron job (runs daily at 04:00 AM)"
        echo "  --remove   Remove the audit cron job"
        echo "  --show     Display current crontab status"
        echo "  --custom   Set a custom schedule then install"
        echo "  --help     Show this help"
        ;;
    *)
        echo "Unknown option: $1. Use --help."
        exit 1
        ;;
esac
