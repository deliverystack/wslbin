# regname.bash: Bash shell script to rename files and directories with invalid names 

This short clog introduces the regname.bash Bash shell script that can rename all files and directories with invalid names that exist within a filesystem.

- https://github.com/deliverystack/wslbin/blob/main/bin/regname.bash

This script uses things like ${1:-.}, shopt -s globstar and possibly other shell features that depend on Bash.

The script starts by scanning the file system for files and directories with names that don’t follow the rules. Then, it prompts the user to rename each identified file or directory, providing a default cleaned up name but allowing the user to override that name. The user can type skip to do nothing and move on to the next file.
