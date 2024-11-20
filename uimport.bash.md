# runzip.bash: Bash shell script to extract/uncompress all volumes

This short clog introduces the uimport.bash Bash shell script that imports unique files.

- https://github.com/deliverystack/wslbin/blob/main/bin/uimport.bash

This script uses things like ${1:-.}, shopt -s globstar and possibly other shell features that depend on Bash.

To extract the unique files from a directory tree, create a new directory, pass the existing directory as the first argument, and pass the new directory as the second argument.