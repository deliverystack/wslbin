#!/usr/bin/bash
# https://chatgpt.com/share/673f52a5-4f04-8005-b334-bdbeafc8ddd6
# ~/git/wslbin/bin/playmed.bash -s 3 -C -d -G -l -r -R -t 3 -V -I -D "/mnt/d/from-onetouch/media/ByYear/2023" -m '/mnt/d/mp3s/XTC'

export NO_FOCUS=true
script_name=$(basename "$0")
trap cleanup INT TERM
color_reset=$(tput sgr0)
color_info=$(tput setaf 2)  # Green
color_warn=$(tput setaf 3)  # Yellow
color_error=$(tput setaf 1) # Red
color_var=$(tput setaf 4)   # Blue
min_time=3
max_time=5
video_duration=10
shuffle=false
debug=false
reverse=false
sort_alpha=false
sort_date=false
install_deps=false
loop=false
include_videos=false
include_gifs=false
sourec_dir="."
audio_files=()
include_info=false
enable_timer=false
pause_audio=false
only_videos=false

log() {
    echo -e "${color_info}${script_name}:${color_reset} $*"
}

warn() {
    echo -e "${color_warn}${script_name}:${color_reset} $*"
}

error() {
    echo -e "${color_error}${script_name}:${color_reset} $*"
}

debug() {
    if ${debug}; then
        echo -e "${color_var}${script_name} (DEBUG):${color_reset} $*"
    fi
}

usage() {
    echo -e "${color_info}${script_name}:${color_reset} Display a slideshow of images, GIFs, and optionally videos."
    echo "Usage: $script_name [options]"
    echo "  -a           Sort images alphabetically (mutually exclusive with -r)."
    echo "  -C           Enable countdown timer for each slide."
    echo "  -d           Enable debug mode."
    echo "  -D <dir>     Specify the directory containing files (default: ${color_var}${target_dir}${color_reset})."
    echo "  -G           Include GIFs with animation."
    echo "  -h           Display this help message."
    echo "  -i           Install missing dependencies (requires sudo)."
    echo "  -I           Include file information in slideshow (via feh's --info option)."
    echo "  -l           Loop slideshow (reshuffles or resorts after completion)."
    echo "  -m <files>   Comma-separated list of FLAC or MP3 files or directories. If directories are specified, adds all .flac and .mp3 files under those directories to the list."
    echo "  -n <min>     Minimum display time for each image (default: ${color_var}${min_time}${color_reset} seconds)."
    echo "  -p           Pause background music during video playback (requires -m)."
    echo "  -O           Only display videos, no images."
    echo "  -r           Randomize file order (mutually exclusive with -a, -x)."
    echo "  -R           Recurse subdirectories when gathering image files."
    echo "  -s <seconds> Maximum display time for each image (default: ${color_var}${max_time}${color_reset} seconds)."
    echo "  -t <seconds> Maximum playback time for videos (default: ${color_var}${video_duration}${color_reset} seconds)."
    echo "  -V           Include video files in the slideshow."
    echo "  -x           Sort files by modification date (mutually exclusive with -r)."
    echo "  -z           Reverse file order (requires -a or -x)."
    exit 1
}

while getopts ":a:CdD:GhIilm:n:pO:rRs:t:Vxz" opt; do
    debug "Processing option: -$opt with argument: $OPTARG"  # Debug
    case ${opt} in
        a) sort_alpha=true ;;
        C) enable_timer=true ;;
        d) debug=true ;;
        D) sourec_dir=$OPTARG ;;  
        G) include_gifs=true ;;
        h) usage ;;
        i) install_deps=true ;;
        I) include_info=true ;;
        l) loop=true ;;
        m) IFS=',' read -r -a audio_files <<< "$OPTARG" ;;
        n) min_time=$OPTARG ;;
        p) pause_audio=true ;;
        O) only_videos=true ;;
        r) shuffle=true ;;
        R) recurse=true ;;
        s) max_time=$OPTARG ;;
        t) video_duration=$OPTARG ;;
        V) include_videos=true ;;
        x) sort_date=true ;;
        z) reverse=true ;;
        \?) warn "Invalid option: -$OPTARG" && usage ;;
    esac
done

log "Debug: sourec_dir is set to: $sourec_dir"


# Validate that -p is only used with -m
if ${pause_audio} && [[ ${#audio_files[@]} -eq 0 ]]; then
    error "The -p option requires background audio files to be specified with -m."
fi

# Validate mutual exclusivity for sorting and randomization
if ${shuffle} && { ${sort_alpha} || ${sort_date}; }; then
    error "The -r (shuffle) option cannot be used with -a (sort alphabetically) or -x (sort by date)."
fi

# Validate that -z (reverse) only works with -a (alphabetical sorting) or -x (date sorting)
if ${reverse} && ! { ${sort_alpha} || ${sort_date}; }; then
    error "The -z (reverse) option requires either -a (sort alphabetically) or -x (sort by date)."
fi

# Validate that -O (only videos) is not used with image options
if ${only_videos} && { ${include_gifs} || ${#audio_files[@]} -gt 0; }; then
    error "The -O (only videos) option cannot be used with -G (include GIFs) or -m (background audio files)."
fi

# Validate that -V (include videos) is not used with -O (only videos)
if ${include_videos} && ${only_videos}; then
    error "The -V (include videos) option cannot be used with -O (only videos)."
fi

# Validate -m (audio files) is required if -p (pause audio during video) is set
if ${pause_audio} && [[ ${#audio_files[@]} -eq 0 ]]; then
    error "The -p option requires background audio files to be specified with -m."
fi

# Validate that both -r (randomize) and -x (sort by date) cannot be used together
if ${shuffle} && ${sort_date}; then
    error "The -r (randomize) option cannot be used with -x (sort by date)."
fi

# Validate -D (directory) argument exists and is a valid directory
if [[ ! -d "${sourec_dir}" ]]; then
    error "The specified directory ${color_var}${sourec_dir}${color_reset} does not exist or is not a directory."
fi

# Ensure -p (pause) is only set when audio files are specified
if ${pause_audio} && [[ ${#audio_files[@]} -eq 0 ]]; then
    error "The -p option requires audio files to be specified using -m."
fi

if [[ -n "$OPTARG" ]]; then
    IFS=',' read -r -a audio_files <<< "$OPTARG"
    for dir in "${audio_files[@]}"; do
        # If it's a directory, find all .flac and .mp3 files under that directory
        if [[ -d "$dir" ]]; then
            log "Adding audio files from directory: ${color_var}$dir${color_reset}"
            # Add all .flac and .mp3 files to the audio_files array
            mapfile -t new_audio_files < <(find "$dir" -type f \( -iname "*.flac" -o -iname "*.mp3" \))
            audio_files+=("${new_audio_files[@]}")  # Add the found files to the existing list
        fi
    done
fi

cleanup() {
    log "Cleaning up and exiting..."
    stop_audio
    pkill -P $$  # Kill all child processes of the current script
    exit 0
}

monitor_exit() {
    while :; do
        read -r -t 1 -n 1 key
        if [[ $key == "q" ]]; then
            cleanup
        fi
    done
}

validate_dependencies() {
    local missing_deps=()
    if ! command -v feh &> /dev/null; then
        missing_deps+=("feh")
    fi
    if ${include_videos} || ${include_gifs} || [[ ${#audio_files[@]} -gt 0 ]]; then
        if ! command -v mpv &> /dev/null; then
            missing_deps+=("mpv")
        fi
    fi

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log "Missing dependencies detected: ${color_var}${missing_deps[*]}${color_reset}"
        echo "To install the missing dependencies, run:"
        echo "  sudo apt update && sudo apt install -y ${missing_deps[*]}"
        exit 1
    fi
}

gather_files() {
    files=()
    if ${recurse}; then
        mapfile -t files < <(find "${sourec_dir}" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.bmp' -o -iname '*.gif' \))
    else
        mapfile -t files < <(find "${sourec_dir}" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.bmp' -o -iname '*.gif' \))
    fi

    if ${include_videos}; then
        if ${recurse}; then
            mapfile -t video_files < <(find "${sourec_dir}" -type f \( -iname '*.mp4' -o -iname '*.mkv' -o -iname '*.avi' -o -iname '*.webm' \))
        else
            mapfile -t video_files < <(find "${sourec_dir}" -maxdepth 1 -type f \( -iname '*.mp4' -o -iname '*.mkv' -o -iname '*.avi' -o -iname '*.webm' \))
        fi
        files+=("${video_files[@]}")
    fi

    if [[ ${#files[@]} -eq 0 ]]; then
        error "No files found in the specified directory."
    fi

    debug "Gathered files: ${color_var}${files[*]}${color_reset}"

    # If -l (loop) is set, ensure that files are available to loop through
    if ${loop} && [[ ${#files[@]} -eq 0 ]]; then
        error "The slideshow cannot loop because no files were found."
    fi
}

sort_and_shuffle_files() {
    if ${sort_alpha}; then
        mapfile -t files < <(printf "%s\n" "${files[@]}" | sort)
    elif ${sort_date}; then
        mapfile -t files < <(printf "%s\n" "${files[@]}" | xargs -I {} stat -c "%Y {}" {} | sort -rn | awk '{print $2}')
    fi

    if ${reverse}; then
        mapfile -t files < <(printf "%s\n" "${files[@]}" | tac)
    fi

    if ${shuffle}; then
        mapfile -t files < <(printf "%s\n" "${files[@]}" | shuf)
    fi
}

countdown_timer() {
    local duration="$1"
    while (( duration > 0 )); do
        echo -ne "${color_info}Time remaining: ${color_var}${duration}${color_reset} seconds...\r"
        sleep 1
        (( duration-- ))
    done
    echo -ne "\r${color_reset}                          \r"  # Clear the line
}

start_audio() {
    if [[ ${#audio_files[@]} -gt 0 ]]; then
        log "Starting background audio playback."
        mpv --loop=inf --no-video --audio-buffer=1.0 "${audio_files[@]}" &
        audio_pid=$!
    fi
}

stop_audio() {
    if [[ -n ${audio_pid} ]]; then
        log "Stopping background audio playback."
        kill "${audio_pid}" &>/dev/null
    fi
}

run_slideshow() {
    log "Starting slideshow..."
    start_audio
    trap cleanup INT TERM  # Handle Ctrl+C or termination

    # Main loop for slideshow
    while :; do
        for file in "${files[@]}"; do
            # Check if it's an image file
            if [[ "${file}" =~ \.(jpg|jpeg|png|bmp|gif)$ ]]; then
                log "Displaying image ${color_var}${file}${color_reset} for ${color_var}${max_time}${color_reset} seconds."


                feh --auto-zoom --fullscreen --borderless --image-bg black -D "${max_time}" --on-last-slide quit --info "realpath \"$file\"" "$file" &
                feh_pid=$!

                # If countdown timer is enabled, show a countdown before the next slide
                [[ ${enable_timer} == true ]] && countdown_timer "${max_time}"

                # Wait for feh to finish before proceeding to the next image
                wait "${feh_pid}"
            fi
        done

        # If loop is enabled, shuffle and restart slideshow
        if ! ${loop}; then
            break
        fi

        log "Restarting slideshow..."
        sort_and_shuffle_files  # Re-sort or shuffle files as needed
    done
}

main() {
    validate_dependencies
    gather_files
    sort_and_shuffle_files
    debug "Files to display: ${color_var}${files[*]}${color_reset}"
    run_slideshow
}

main
exit





git clone git@github.com:username/repository.git