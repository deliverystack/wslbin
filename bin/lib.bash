#!/bin/bash
script_name=$(basename "$0")

log_output="both"  # Options: screen, file, both
log_file="/tmp/${script_name}.$$.$USER.$(date +%Y%m%d%H%M%S).log"
debug=true  # Debug mode off by default
verbose=true  # Verbose mode off by default

red_color=$(tput setaf 1)
green_color=$(tput setaf 2)
orange_color=$(tput setaf 3)
yellow_color=$(tput setaf 3)
blue_color=$(tput setaf 4)
reset_color=$(tput sgr0)

red() { printf "${red_color}%s${reset_color}" "$1"; }
green() { printf "${green_color}%s${reset_color}" "$1"; }
orange() { printf "${orange_color}%s${reset_color}" "$1"; }
yellow() { printf "${yellow_color}%s${reset_color}" "$1"; }
blue() { printf "${blue_color}%s${reset_color}" "$1"; }

log_message() {
    local level="$1"
    local level_color="$2"
    shift 2 
    local timestamp
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")

    for message in "$@"; do
        local entry="${level_color}${script_name}: ${level}: ${reset_color}${message}"

        if [[ "$log_output" == "screen" || "$log_output" == "both" ]]; then
            printf "%s\n" "$entry" > /dev/tty
        fi

        if [[ "$log_output" == "file" || "$log_output" == "both" ]]; then
            printf "%s %s\n" "$timestamp" "$entry" >> "$log_file"
        fi
    done
}

info() {
    local level="INFO"
    local color="$green_color"
    log_message "$level" "$color" "$@"
}

warn() {
    local level="WARN"
    local color="$orange_color"
    log_message "$level" "$color" "$@"
}

error() {
    local level="ERROR"
    local color="$red_color"
    log_message "$level" "$color" "$@"
}

debug() {
    local level="DEBUG"
    local color="$yellow_color"
    [[ "$debug" == true ]] && log_message "$level" "$color" "$@"
}

sanitize_name_part() {
    local part="$1"
    echo "$part" | sed -E "
        s|[^a-zA-Z0-9.-]|-|g;  # Replace invalid characters
        s|-{2,}|-|g;           # Remove repeated dashes
        s|^-||g;               # Remove leading dashes
        s|-$||g;               # Remove trailing dashes
    " | tr '[:upper:]' '[:lower:]'
}

clean_name() {
    local original="$1"
    local base
    local ext=""
    local cleaned_base
    local cleaned_ext

    debug "Processing name: ${original}"

    # Split the name into base and extension
    base="${original%.*}"
    ext="${original##*.}"

    # Handle cases where there's no extension
    if [[ "$base" == "$original" ]]; then
        ext=""
    fi
    debug "Split name into base: '${base}', extension: '${ext}'"

    # Sanitize the base and extension
    cleaned_base=$(sanitize_name_part "$base")
    if [[ -n "$ext" ]]; then
        cleaned_ext=$(sanitize_name_part "$ext")
    else
        cleaned_ext=""
    fi

    # Combine base and extension
    if [[ -n "$cleaned_ext" ]]; then
        cleaned_base="${cleaned_base}.${cleaned_ext}"
    fi

    # Handle edge cases for short or invalid names
    if [[ -z "$cleaned_base" || "$cleaned_base" =~ ^-+$ ]]; then
        cleaned_base="file-${RANDOM}"
    fi

    debug "Sanitized name: ${cleaned_base}"
    echo "$cleaned_base"
}

run_command() {
    local cmd=""
    local output_file=""
    local debug=false
    local verbose=false
    local log_file="$HOME/cmd.log"
    local result
    local risk=false
    local calling_script
    local start_time

    # Parse arguments
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            -o|--output-file)
                output_file="$2"
                shift
                ;;
            -d|--debug)
                debug=true
                ;;
            -v|--verbose)
                verbose=true
                ;;
            *)
                cmd="$*"
                break
                ;;
        esac
        shift
    done

    if [[ -z "$cmd" ]]; then
        warn "No command provided to run_command"
        return 1
    fi

    # Get calling script and timestamp
    calling_script="$(realpath "${BASH_SOURCE[1]}")"
    start_time=$(date '+%Y-%m-%d %H:%M:%S')

    # Log command invocation
    info "Executing command: \"$cmd\" from \"$calling_script\""

    # Execute the command
    if [[ -n "$output_file" ]]; then
        debug "Saving command output to: $output_file"
        eval "$cmd" 2>&1 | tee "$output_file" > /dev/tty
    else
        debug "No output file specified; command output will not be saved."
        eval "$cmd" &>/dev/null
    fi

    result=${PIPESTATUS[0]}

    # Detect risk based on command output
    if [[ -n "$output_file" && -f "$output_file" ]]; then
        if grep -qiE 'error|warning' "$output_file"; then
            risk=true
        fi
    fi

    # Log command metadata (excluding output)
    info "Command completed: \"$cmd\" (Result: $result, Risk: $risk)"
    {
        echo "  {"
        echo "    \"timestamp\": \"$start_time\","
        echo "    \"calling_script\": \"$calling_script\","
        echo "    \"command\": \"$cmd\","
        echo "    \"result\": $result,"
        echo "    \"risk\": $risk"
        echo "  }"
    } >> "$log_file"

    # Do not print JSON to the screen
    local output_file_json="${output_file:-null}"
    echo "{\"result\": $result, \"risk\": $risk, \"output_file\": \"$output_file_json\"}"
    printf '{"result": %d, "risk": %s, "output_file": "%s"}\n' "$result" "$risk" "$output_file_json" >> "$log_file"
}

self_check() {
    local calling_script
    calling_script=$(realpath "${BASH_SOURCE[0]}")
    local json
    # Execute ShellCheck and capture JSON output
    json=$(run_command -v shellcheck "$calling_script")

    # Validate JSON
    if ! jq -e . <<<"$json" >/dev/null 2>&1; then
        error "Error: Invalid JSON output from run_command:"
        echo "$json"
        return 1
    fi

    # Extract result and risk
    local result risk output_file
    result=$(jq -r '.result' <<<"$json")
    risk=$(jq -r '.risk' <<<"$json")
    output_file=$(jq -r '.output_file // null' <<<"$json")

    # Display results
    if [[ "$result" -eq 0 && "$risk" == "false" ]]; then
        debug "ShellCheck passed successfully."
    else
        warn "ShellCheck reported issues:"
        if [[ "$output_file" != "null" && -n "$output_file" && -f "$output_file" ]]; then
            cat "$output_file"
        elif [[ "$output_file" != "null" && -n "$output_file" && -f "$output_file" ]]; then
            cat "$output_file"
        else
            warn "No output available. Pass -o or --output-file to run_command to capture output."
        fi
    fi
}

# Example usage of the script
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    debug=true  # Enable debug for testing
    verbose=true  # Enable verbose for testing

    info "Starting script self-check using ShellCheck..."
    self_check

    json=$(run_command --invalid)

    # Parse the result and check for errors
    if ! jq -e . <<<"$json" >/dev/null 2>&1; then
        error "Error: Invalid JSON output from run_command:"
        debug "$json"
    else
        result=$(jq -r '.result' <<<"$json")
        risk=$(jq -r '.risk' <<<"$json")
        output_file=$(jq -r '.output_file // null' <<<"$json")

        if [[ "$result" -ne 0 || "$risk" == "true" ]]; then
            error "Command failed with result: $result and risk: $risk."
            if [[ "$output_file" != "null" && -f "$output_file" ]]; then
                warn "Command output saved in: $output_file"
            else
                warn "No output available. Use -o to capture output."
            fi
        else
            info "Command executed successfully."
            if [[ "$output_file" != "null" && -f "$output_file" ]]; then
                info "Command output saved in: $output_file"
            fi
        fi
    fi

    # Run a non-existent directory listing command to demonstrate error handling
    json=$(run_command ls /nonexistent_directory)

    # Parse the result and check for errors
    if ! jq -e . <<<"$json" >/dev/null 2>&1; then
        error "Error: Invalid JSON output from run_command:"
        debug "$json"
    else
        result=$(jq -r '.result' <<<"$json")
        risk=$(jq -r '.risk' <<<"$json")
        output_file=$(jq -r '.output_file // null' <<<"$json")

        if [[ "$result" -ne 0 || "$risk" == "true" ]]; then
            error "Command failed with result: $result and risk: $risk."
            if [[ "$output_file" != "null" && -f "$output_file" ]]; then
                warn "Command output saved in: $output_file"
            else
                warn "No output available. Use -o to capture output."
            fi
        else
            info "Command executed successfully."
            if [[ "$output_file" != "null" && -f "$output_file" ]]; then
                info "Command output saved in: $output_file"
            fi
        fi
    fi
    info "Sanitizing a sample filename..."
    sanitized_name=$(clean_name " Example--File!@Name  ")
    info "Sanitized filename: $(blue "${sanitized_name}")"
fi


