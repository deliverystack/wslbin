#!/usr/bin/bash

shopt -s globstar

prefix="$(tput setaf 2)$(basename "$0")$(tput sgr0)"

yellow() { tput setaf 3; echo -n "$1"; tput sgr0; }
red() { tput setaf 1; echo -n "$1"; tput sgr0; }

# invalid_chars="&?/'\":"
invalid_pattern="[&?/'\":\[\]]|[.]$|[[:space:]]$"

clean_name() {
    echo "$1" | sed "s|[&?/'\":\[\]]|-|g; s|[.]$||; s|[[:space:]]$||"
}

prompt_rename() {
    local old_name="$1"
    local default_new_name
    default_new_name=$(clean_name "$(basename "$old_name")")
    printf "%s: Invalid file name detected: %s\n" "$prefix" "$(yellow "$old_name")"
    read -p "Enter new name [default: $default_new_name, skip to move on]: " new_name
    if [ -z "$new_name" ]; then
        new_name="$default_new_name"
    elif [ "$new_name" = "skip" ]; then
        printf "%s: Skipping: %s\n" "$prefix" "$(yellow "$old_name")"
        return
    fi
    mv "$old_name" "$(dirname "$old_name")/$new_name" || {
        printf "%s: Failed to rename %s.\n" "$prefix" "$(yellow "$old_name")"
    }
}

usage() {
    printf "%s: Usage: %s [directory]\n" "$prefix" "$prefix"
    exit 1
}

directory="${1:-.}"

if [ ! -d "$directory" ]; then
    printf "%s: Directory %s does not exist.\n" "$prefix" "$(red "$directory")"
    usage
fi

start_time=$(date +%s)
full_path=$(realpath "$directory")
printf "%s: Finding all files and subdirectories under: %s\n" "$prefix" "$full_path"

invalid_files=()

for file in "$directory"/**/*; do
    if [ -e "$file" ]; then
        base_name=$(basename "$file")
        if [[ "$base_name" =~ $invalid_pattern ]]; then
            invalid_files+=("$file")
        fi
    fi
done

end_time=$(date +%s)
elapsed=$((end_time - start_time))
printf "%s: Globbing took %'d seconds.\n" "$prefix" "$elapsed"

num_invalid_files=${#invalid_files[@]}
printf "%s: Found %'d invalid files and/or directories.\n" "$prefix" "$num_invalid_files"

for file in "${invalid_files[@]}"; do
    prompt_rename "$file"
done

printf "%s: Completed processing invalid files and directories.\n" "$prefix"
