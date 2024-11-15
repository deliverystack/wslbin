# runzip.bash: Bash shell script to extract/uncompress all volumes

This short clog introduces the runzip.bash Bash shell script that decompresses inline all volumes under a root directory, deleting the original volumes.

- https://github.com/deliverystack/wslbin/blob/main/bin/runzip.bash

This script uses things like ${1:-.}, shopt -s globstar and possibly other shell features that depend on Bash.