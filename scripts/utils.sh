#!/bin/bash
# =============================================================================
# FILE        : utils.sh
# DESCRIPTION : Shared utility/helper functions used across all modules
# AUTHOR      : NSCS Students - Group Project
# DATE        : 2026
# =============================================================================

# =============================================================================
# FUNCTION: log_message
# PURPOSE : Write a timestamped log entry to the log file AND print to terminal
# ARGS    : $1 = level (INFO | WARNING | ERROR), $2 = message
# =============================================================================
log_message() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Make sure log directory exists before writing
    mkdir -p "$LOG_DIR"

    local log_file="$LOG_DIR/audit_execution.log"
    echo "[$timestamp] [$level] $message" >> "$log_file"

    # Also print to terminal with color based on level
    case "$level" in
        INFO)    echo -e "${GREEN}[INFO]${NC}    $message" ;;
        WARNING) echo -e "${YELLOW}[WARNING]${NC} $message" ;;
        ERROR)   echo -e "${RED}[ERROR]${NC}   $message" ;;
        *)       echo "[$level] $message" ;;
    esac
}

# =============================================================================
# FUNCTION: check_command
# PURPOSE : Check if a system command/tool is available before using it
# ARGS    : $1 = command name
# RETURNS : 0 if found, 1 if not found
# =============================================================================
check_command() {
    local cmd="$1"
    if command -v "$cmd" &>/dev/null; then
        return 0   # command exists
    else
        log_message "WARNING" "Command not found: $cmd — skipping related section."
        return 1   # command does not exist
    fi
}

# =============================================================================
# FUNCTION: section_header
# PURPOSE : Print a nicely formatted section header in the terminal
# ARGS    : $1 = title text
# =============================================================================
section_header() {
    local title="$1"
    echo ""
    echo -e "${CYAN}============================================================${NC}"
    echo -e "${CYAN}  $title${NC}"
    echo -e "${CYAN}============================================================${NC}"
}

# =============================================================================
# FUNCTION: print_info
# PURPOSE : Print a key-value pair in a formatted way
# ARGS    : $1 = label, $2 = value
# =============================================================================
print_info() {
    local label="$1"
    local value="$2"
    printf "  ${BOLD}%-28s${NC} %s\n" "$label:" "$value"
}

# =============================================================================
# FUNCTION: get_timestamp
# PURPOSE : Return a clean timestamp string (used for filenames and reports)
# =============================================================================
get_timestamp() {
    date '+%Y-%m-%d_%H-%M-%S'
}

# =============================================================================
# FUNCTION: get_date_readable
# PURPOSE : Return a human-readable date for report headers
# =============================================================================
get_date_readable() {
    date '+%A, %B %d, %Y - %H:%M:%S'
}

# =============================================================================
# FUNCTION: rotate_logs
# PURPOSE : Keep only the last N log files to avoid filling up disk space
# ARGS    : $1 = directory, $2 = max number of files to keep
# =============================================================================
rotate_logs() {
    local dir="$1"
    local max_files="${2:-10}"   # default: keep last 10 files

    # Count files in the directory
    local count
    count=$(ls -1 "$dir" 2>/dev/null | wc -l)

    # If there are more files than allowed, delete the oldest ones
    if [ "$count" -gt "$max_files" ]; then
        local to_delete=$(( count - max_files ))
        ls -1t "$dir" | tail -n "$to_delete" | while read -r f; do
            rm -f "$dir/$f"
            log_message "INFO" "Log rotation: deleted old file $f"
        done
    fi
}

# =============================================================================
# FUNCTION: verify_log_integrity
# PURPOSE : Create or verify a SHA256 hash of a report file (tamper detection)
# ARGS    : $1 = file path, $2 = "create" or "verify"
# =============================================================================
verify_log_integrity() {
    local file="$1"
    local action="$2"
    local hash_file="${file}.sha256"

    if [ ! -f "$file" ]; then
        log_message "ERROR" "File not found for integrity check: $file"
        return 1
    fi

    if [ "$action" = "create" ]; then
        # Generate hash and save it to a .sha256 file next to the report
        sha256sum "$file" > "$hash_file"
        log_message "INFO" "Hash created for: $file"

    elif [ "$action" = "verify" ]; then
        if [ ! -f "$hash_file" ]; then
            log_message "WARNING" "No hash file found for: $file"
            return 1
        fi
        # Verify the file matches its saved hash
        if sha256sum -c "$hash_file" &>/dev/null; then
            echo -e "${GREEN}[OK] File integrity verified: $file${NC}"
            log_message "INFO" "Integrity OK: $file"
        else
            echo -e "${RED}[ALERT] File has been MODIFIED: $file${NC}"
            log_message "ERROR" "Integrity FAILED: $file"
        fi
    fi
}

# =============================================================================
# FUNCTION: check_cpu_alert
# PURPOSE : Check current CPU usage and send alert if it exceeds threshold
# =============================================================================
check_cpu_alert() {
    section_header "CPU Usage Alert Check"

    # Get CPU idle percentage using top, then calculate usage
    local cpu_idle
    cpu_idle=$(top -bn1 | grep "Cpu(s)" | awk '{print $8}' | tr -d '%,')

    # Handle different top output formats
    if [ -z "$cpu_idle" ]; then
        cpu_idle=$(top -bn1 | grep "Cpu(s)" | sed 's/.*,\s*\([0-9.]*\)\s*id.*/\1/')
    fi

    # Calculate CPU usage = 100 - idle
    local cpu_usage
    cpu_usage=$(echo "100 - ${cpu_idle:-0}" | bc 2>/dev/null || echo "N/A")

    print_info "CPU Usage" "${cpu_usage}%"
    print_info "Alert Threshold" "${CPU_ALERT_THRESHOLD}%"

    # Compare usage to threshold (using bc for decimal comparison)
    if [ "$cpu_usage" != "N/A" ]; then
        local is_over
        is_over=$(echo "$cpu_usage > $CPU_ALERT_THRESHOLD" | bc 2>/dev/null)
        if [ "$is_over" = "1" ]; then
            echo -e "${RED}[ALERT] CPU usage is above ${CPU_ALERT_THRESHOLD}%! Current: ${cpu_usage}%${NC}"
            log_message "WARNING" "CPU ALERT: usage=${cpu_usage}% threshold=${CPU_ALERT_THRESHOLD}%"
            # You can also call send_report_email here to alert by email
        else
            echo -e "${GREEN}[OK] CPU usage is within normal range.${NC}"
            log_message "INFO" "CPU OK: usage=${cpu_usage}%"
        fi
    else
        log_message "WARNING" "Could not determine CPU usage"
    fi
}

# =============================================================================
# FUNCTION: compare_reports
# PURPOSE : Compare two report files and show what changed between them
# =============================================================================
compare_reports() {
    section_header "Compare Two Reports"

    # List available reports for user to pick from
    echo "Available reports in $REPORT_DIR:"
    ls -1 "$REPORT_DIR"/*.txt 2>/dev/null || {
        echo -e "${RED}No .txt reports found in $REPORT_DIR${NC}"
        return 1
    }

    echo ""
    echo -n "Enter path to FIRST report: "
    read -r report1
    echo -n "Enter path to SECOND report: "
    read -r report2

    # Input validation
    if [ ! -f "$report1" ]; then
        log_message "ERROR" "First report not found: $report1"
        return 1
    fi
    if [ ! -f "$report2" ]; then
        log_message "ERROR" "Second report not found: $report2"
        return 1
    fi

    echo ""
    echo -e "${CYAN}--- Differences between reports ---${NC}"
    # diff shows lines that changed: lines with < are from file1, > from file2
    diff "$report1" "$report2" || echo -e "${YELLOW}(Files are identical)${NC}"

    log_message "INFO" "Compared: $report1 vs $report2"
}
