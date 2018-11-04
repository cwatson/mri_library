#! /bin/bash
# Some utility functions
# Christopher G. Watson, 2018-11-03

myred=$(tput setaf 1)
mygreen=$(tput setaf 2)
myyellow=$(tput setaf 3)

# Check software; print error if absent
#
# $1 - the name of the binary to search for
# $2 - the software name to print in the error message
# $3 - the exit code to use
#
# Examples
#
#    check_sw convert "the 'ImageMagick' suite" 105
#
check_sw() {
    has_sw=$(type -P ${1})
    if [[ $? -ne 0 ]]; then
        echo -ne "$(tput bold)${myred}\nERROR: "
        echo "Please install ${2}!"
        exit ${3}
    fi
}

export myred mygreen myyellow
export -f check_sw
