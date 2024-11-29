# source this code in Bash shells to replace the cd command as described at
# https://wslguy.net/2024/11/28/wsl-bash-cd-enhancement-to-track-directories-across-sessions/

jd() {
    func_name="${FUNCNAME[0]}"
    dir_file="${HOME}/.${func_name}.lst"
    touch "${dir_file}"

    resolve_path() {
        local input_path="$1"

        if [[ "$input_path" =~ ^\\\\ || "$input_path" =~ ^[a-zA-Z]: ]]; then
            if [[ "$input_path" =~ ^[a-zA-Z]:$ ]]; then
                input_path="${input_path}\\"
            fi
            input_path=$(wslpath -u "$input_path" 2>/dev/null || echo "$input_path")
        fi

        local resolved
        resolved=$(realpath -m "$input_path" 2>/dev/null) || return 1

        if [[ "$resolved" != "/" ]]; then
            resolved="${resolved%/}"
        fi
        echo "${resolved}/"
    }

    # Variables to collect options and directory
    local cd_opts=""
    local target_dir=""
    local args=()

    # Collect options and positional arguments
    while [[ "$1" ]]; do
        case "$1" in
            -L|-P|-e|-@) cd_opts+=" $1" ;;  # Collect options
            -h)
                cat <<EOF
Usage: ${func_name} [-L|-P|-e|-@] [DIRECTORY|-l|-n NUMBER]
  DIRECTORY      Change to the specified directory.
  -l             List tracked directories with line numbers.
  -n NUMBER      Change to the directory at the specified line.
  -              Switch to the previous directory.
Options:
  -L             Follow symbolic links (default).
  -P             Use the physical directory structure.
  -e             Exit with non-zero if current working directory fails.
  -@             On supported systems, show extended file attributes.
EOF
                return 0
                ;;
            -l)
                nl -w 4 -s ": " "${dir_file}"
                return 0
                ;;
            -n)
                shift
                if [[ -z "$1" || ! "$1" =~ ^[0-9]+$ ]]; then
                    echo "Error: Please provide a valid line number." >&2
                    return 1
                fi
                target_dir=$(sed -n "${1}p" "${dir_file}")
                if [[ -z "${target_dir}" ]]; then
                    echo "Error: No directory at line $1." >&2
                    return 1
                fi
                ;;
            *)
                args+=("$1")  # Collect positional arguments (directory paths)
                ;;
        esac
        shift
    done

    # Determine the directory to navigate to
    local new_dir="${args[0]:-}"
    if [[ -n "$target_dir" ]]; then
        new_dir="$target_dir"
    elif [[ -z "$new_dir" && -z "$target_dir" ]]; then
        new_dir="$HOME"
    fi

    if [[ "$new_dir" == "-" ]]; then
        if [[ -z "${OLDPWD}" ]]; then
            echo "Error: No previous directory to switch to." >&2
            return 1
        fi
        new_dir="${OLDPWD}"
    fi

    local resolved_path
    resolved_path=$(resolve_path "$new_dir") || {
        echo "Error: Failed to resolve path: $new_dir" >&2
        return 1
    }

    local prev_dir="${PWD}"
    builtin cd $cd_opts "$resolved_path" 2>/dev/null
    local cd_exit_code=$?  # Capture the exit code of `cd`

    if [[ $cd_exit_code -ne 0 ]]; then
        echo "Error: Failed to change directory to ${resolved_path}." >&2
        return $cd_exit_code  # Return the same exit code as `cd`
    fi

    export OLDPWD="${prev_dir}"

    if ! grep -Fxq "${PWD}/" "${dir_file}"; then
        echo "${PWD}/" >> "${dir_file}"
    fi

    return $cd_exit_code  # Ensure the function returns the same exit code as `cd`
}

alias cd='jd'