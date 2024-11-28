# playmed.bash: WSL Bash Shell Script for Image/Video/Audio Slideshow

Clippy 2.0 I and I wrote a Bash shell script to render a slideshow from the images and videos under a root directory. It makes it worth pulling the media from the phones to a PC, and the kids love it. I haven’t tested much, and only under WSL and Ubuntu itself, but according to Clippy:

# Multimedia Slideshow Script

This Bash script allows you to create a multimedia slideshow with support for images, videos, and optional background audio. It provides options to customize playback behavior, file sorting, and looping.

## Overview
The script:
- Displays images and plays videos in fullscreen.
- Supports background music during the slideshow.
- Allows sorting and randomization of files.
- Enables custom playback settings like display time for images and maximum video duration.
- Validates all dependencies and options before running.

## Features
1. **Image and Video Playback**: Displays images and plays videos in a fullscreen slideshow.
2. **Audio Playback**: Supports background music during the slideshow.
3. **Sorting and Order Control**:
   - Alphabetical or date-based sorting.
   - Shuffle/randomize the playback order.
   - Reverse the order of files.
4. **Looping**: Repeats the slideshow until interrupted.
5. **Custom Playback Settings**:
   - Control display time for images.
   - Limit playback duration for videos.
   - Pause background music during video playback.
6. **Subdirectory Support**: Optionally includes files from subdirectories.
7. **Dependency Validation**: Checks if required tools (`feh`, `mpv`) are installed.

## Command-Line Options

| **Option** | **Description**                                                                                               |
|------------|---------------------------------------------------------------------------------------------------------------|
| `-a`       | Sort images and videos alphabetically. Cannot be used with `-r` (randomize).                                   |
| `-d <dir>` | Specify the source directory for files. Defaults to the current directory (`.`).                              |
| `-h`       | Display a help message and exit.                                                                              |
| `-i`       | Include file information (metadata) in the slideshow.                                                         |
| `-I`       | Include images in the slideshow.                                                                              |
| `-l`       | Loop the slideshow. After completing all files, reshuffles or resorts based on the specified sorting options.  |
| `-m <files>`| Comma-separated list of audio files or directories to play as background music. If directories are specified, all `.mp3` and `.flac` files within will be added. |
| `-n <sec>` | Specify the display time for each image (default: 5 seconds).                                                 |
| `-p`       | Pause background audio playback during video playback. Requires `-m`.                                         |
| `-r`       | Randomize file order. Cannot be used with `-a` (alphabetical) or `-x` (date-based sorting).                   |
| `-R`       | Include files from subdirectories.                                                                            |
| `-t <sec>` | Specify the maximum playback time for videos (default: 0, no limit).                                          |
| `-v`       | Enable verbose mode for additional logging.                                                                   |
| `-V`       | Include video files in the slideshow.                                                                         |
| `-x`       | Sort files by modification date. Cannot be used with `-r`.                                                    |
| `-z`       | Reverse file order. Requires `-a` (alphabetical) or `-x` (date-based sorting).                                |

## Usage
Run the script with the desired options. For example:
```bash
./playmed.bash -d /path/to/files -I -V -m background.mp3 -n 10 -r -l
```

This command:
- Includes images (`-I`) and videos (`-V`) from `/path/to/files`.
- Plays background music from `background.mp3`.
- Displays each image for 10 seconds (`-n 10`).
- Randomizes the file order (`-r`) and loops the slideshow (`-l`).

## Dependencies
The script requires the following tools:
- `feh`: For image display.
- `mpv`: For video playback and background music.

If any dependencies are missing, the script will notify you and provide installation instructions.

## Error Handling
The script performs validations for:
- Mutually exclusive options (e.g., `-a` with `-r`).
- Missing required options or invalid values.
- Missing dependencies.

It provides detailed error messages to guide the user.

---

- https://github.com/deliverystack/wslbin/blob/main/bin/playmed.bash
- https://chatgpt.com/share/673f52a5-4f04-8005-b334-bdbeafc8ddd6 (and some other threads; fighting Clippy took a bit of work!)


