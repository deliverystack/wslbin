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
video_duration=0
shuffle=false
debug=false
reverse=false
sort_alpha=false
sort_date=false
loop=false
include_videos=false
include_gifs=false
source_dir="."
audio_files=()
include_info=false
enable_timer=false
pause_audio=false
only_videos=false
add_subtitles=false  

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
    cat <<EOF
${color_info}${script_name}:${color_reset} Display a slideshow of images, GIFs, and optionally videos.
Usage: $script_name [options]
  -a           Sort images alphabetically (mutually exclusive with -r).
  -C           Enable countdown timer for each slide.
  -d           Enable debug mode.
  -D <dir>     Specify the directory containing files (default: ${color_var}${source_dir}${color_reset}).
  -G           Include GIFs with animation.
  -h           Display this help message.
  -i           Include file information in slideshow (via feh's --info option).
  -l           Loop slideshow (reshuffles or resorts after completion).
  -m <files>   Comma-separated list of FLAC or MP3 files or directories. If directories are specified, adds all .flac and .mp3 files under those directories to the list.
  -n <min>     Minimum display time for each image (default: ${color_var}${min_time}${color_reset} seconds).
  -p           Pause background music during video playback (requires -m).
  -O           Only display videos, no images.
  -r           Randomize file order (mutually exclusive with -a, -x).
  -R           Recurse subdirectories when gathering image files.
  -s <seconds> Maximum display time for each image (default: ${color_var}${max_time}${color_reset} seconds).
  -S           Add file path and name as a subtitle to videos.
  -t <seconds> Maximum playback time for videos (default: ${color_var}${video_duration}${color_reset} seconds).
  -V           Include video files in the slideshow.
  -x           Sort files by modification date (mutually exclusive with -r).
  -z           Reverse file order (requires -a or -x).
EOF
    exit 1
}

while getopts ":a:CdD:Ghilm:n:pOrRs:St:Vxz" opt; do
    case ${opt} in
        a) sort_alpha=true ;;
        C) enable_timer=true ;;
        d) debug=true ;;
        D) source_dir=$OPTARG ;;  
        G) include_gifs=true ;;
        h) usage ;;
        i) include_info=true ;;
        l) loop=true ;;
        m) IFS=',' read -r -a audio_files <<< "$OPTARG" ;;
        n) min_time=$OPTARG ;;
        p) pause_audio=true ;;
        O) only_videos=true ;;
        r) shuffle=true ;;
        R) recurse=true ;;
        s) max_time=$OPTARG ;;
        S) add_subtitles=true ;;
        t) video_duration=$OPTARG ;;
        V) include_videos=true ;;
        x) sort_date=true ;;
        z) reverse=true ;;
        \?) warn "Invalid option: -$OPTARG" && usage ;;
    esac
done

if ${pause_audio} && [[ ${#audio_files[@]} -eq 0 ]]; then
    error "The -p option requires background audio files to be specified with -m."
fi

if ${shuffle} && { ${sort_alpha} || ${sort_date}; }; then
    error "The -r (shuffle) option cannot be used with -a (sort alphabetically) or -x (sort by date)."
fi

if ${reverse} && ! { ${sort_alpha} || ${sort_date}; }; then
    error "The -z (reverse) option requires either -a (sort alphabetically) or -x (sort by date)."
fi

if [[ "${only_videos}" == "true" ]] && { [[ "${include_gifs}" == "true" ]] || [[ ${#audio_files[@]} -gt 0 ]]; }; then
    error "The -O (only videos) option cannot be used with -G (include GIFs) or -m (background audio files)."
fi

if ${include_videos} && ${only_videos}; then
    error "The -V (include videos) option cannot be used with -O (only videos)."
fi

if ${pause_audio} && [[ ${#audio_files[@]} -eq 0 ]]; then
    error "The -p option requires background audio files to be specified with -m."
fi

if ${shuffle} && ${sort_date}; then
    error "The -r (randomize) option cannot be used with -x (sort by date)."
fi

if [[ ! -d "${source_dir}" ]]; then
    error "The specified directory ${color_var}${source_dir}${color_reset} does not exist or is not a directory."
fi

if ${pause_audio} && [[ ${#audio_files[@]} -eq 0 ]]; then
    error "The -p option requires audio files to be specified using -m."
fi

if [[ -n "$OPTARG" ]]; then
    IFS=',' read -r -a audio_files <<< "$OPTARG"
    for dir in "${audio_files[@]}"; do
        if [[ -d "$dir" ]]; then
            log "Adding audio files from directory: ${color_var}$dir${color_reset}"
            mapfile -t new_audio_files < <(find "$dir" -type f \( -iname "*.flac" -o -iname "*.mp3" \))
            audio_files+=("${new_audio_files[@]}")  # Add the found files to the existing list
        fi
    done
fi

cleanup() {
    log "Cleaning up and exiting..."
    stop_audio
    pkill -P $$  # Kill all child processes of the current script
    stty sane
    exit 0
}

validate_dependencies() {
    local missing_deps=()
    if ! command -v feh &> /dev/null; then
        missing_deps+=("feh")
    fi
    if ! command -v convert &> /dev/null; then
        missing_deps+=("imagemagick")
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

    if [[ "${only_videos}" != "true" ]]; then
        if ${recurse}; then
            mapfile -t files < <(find "${source_dir}" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.bmp' -o -iname '*.gif' \))
        else
            mapfile -t files < <(find "${source_dir}" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.bmp' -o -iname '*.gif' \))
        fi
    fi

    if ${include_videos}; then
        if ${recurse}; then
            mapfile -t video_files < <(find "${source_dir}" -type f \( -iname '*.mp4' -o -iname '*.mkv' -o -iname '*.avi' -o -iname '*.webm' \))
        else
            mapfile -t video_files < <(find "${source_dir}" -maxdepth 1 -type f \( -iname '*.mp4' -o -iname '*.mkv' -o -iname '*.avi' -o -iname '*.webm' \))
        fi
        files+=("${video_files[@]}")
    fi

    if [[ ${#files[@]} -eq 0 ]]; then
        error "No files found in the specified directory."
    fi

    debug "Gathered files: ${color_var}${files[*]}${color_reset}"

    if ${loop} && [[ ${#files[@]} -eq 0 ]]; then
        error "The slideshow cannot loop because no files were found."
        exit
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

monitor_exit() {
    while :; do
        read -r -t 1 -n 1 key
        if [[ $key == "q" ]]; then
            cleanup
        fi
    done
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
                local display_file="$file"
                log "Displaying image ${color_var}${display_file}${color_reset} for ${color_var}${max_time}${color_reset} seconds."

#                feh --auto-zoom --auto-rotate --fullscreen --borderless --image-bg black -D "${max_time}" --on-last-slide quit \
#                    $( [ "$include_info" = true ] && echo "--info \"bash -c '$info_cmd'\"" ) "$display_file" &

                feh --auto-zoom --auto-rotate --fullscreen --borderless --image-bg black -D 5 --on-last-slide quit \
                    --info "bash -c 'realpath \"$file\"'" "$file" &



                feh_pid=$!
                [[ ${enable_timer} == true ]] && countdown_timer "${max_time}"
                wait "${feh_pid}"
            # Check if it's a video file
            elif [[ "${file}" =~ \.(mp4|mkv|avi|webm)$ ]]; then
                log "Playing video ${color_var}${file}${color_reset} for up to ${color_var}${video_duration}${color_reset} seconds."

                # Initialize the mpv command
                mpv_cmd="mpv --fs --audio-device=pulse --hwdec=auto-safe --msg-level=vo/gpu=warn --fs --hwdec=auto-safe --vo=gpu --gpu-context=wayland"

                if [[ ${video_duration} -ne 0 ]]; then
                    mpv_cmd+=" --length=${video_duration}"
                fi

                # Only create subtitle file if -S option is set
                if ${add_subtitles}; then
                    subtitle_file=$(mktemp "/tmp/$(basename "${file%.*}").XXXXXX.srt")
                    echo "1" > "${subtitle_file}"  # Subtitle index
                    echo "00:00:00,000 --> 00:00:10,000" >> "${subtitle_file}"  # Time format (adjust duration if needed)
                    realpath --relative-to="${source_dir}" "$file" >> "${subtitle_file}"  
                    mpv_cmd="$mpv_cmd --sub-file=\"${subtitle_file}\""
                    log "Subtitle file ${color_var}${subtitle_file}${color_reset} created."
                fi

                # Add the video file to the command
                mpv_cmd="$mpv_cmd \"$(realpath "$file")\""
                if ${pause_audio} && [[ -n ${audio_pid} ]]; then
                    log "Pausing background music."
                    kill -SIGSTOP "${audio_pid}"  # Pause audio playback
                fi

                # Execute the constructed mpv command
#                eval "$mpv_cmd --profile=fast --hwdec=auto-safe"
echo $mpv_cmd
                eval "$mpv_cmd" 

                # Clean up the temporary subtitle file after playback (if created)
                if ${add_subtitles}; then
                    rm -f "${subtitle_file}"
                fi

                if ${pause_audio} && [[ -n ${audio_pid} ]]; then
                    log "Resuming background music."
                    kill -SIGCONT "${audio_pid}"  # Resume audio playback
                fi
            fi
        done

        # If loop is enabled, reshuffle or restart slideshow
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