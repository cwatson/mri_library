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

# Log software version information in a JSON file
#
# $1 - the name of the binary
# $2 - the JSON file to add to, if it exists
#
# Examples
#
#    log_sw_info dcmtk preproc.json

log_sw_info() {
    if [[ $# -lt 1 ]]; then
        echo "Please supply the name of a binary/program!"
        exit 10
    elif [[ $# -lt 2 ]]; then
        outfile=preproc.json
        if [[ ! -f ${outfile} ]]; then
            touch ${outfile}
        fi
    else
        outfile=${2}
    fi
    case ${1} in
        dcmtk)  ver=$(dcmdump --version | awk '{print $3,$4}' | head -1) ;;
        jo)     ver=$(jo -v | awk '{print $2}') ;;
        jq)
            jqver=$(jq -V 2>&1)
            case ${jqver} in
                *1.[0-3]*)  ver=$(echo ${jqver} | awk '{print $3}') ;;
                *)          ver=$(echo ${jqver} | awk -F- '{print $2}') ;;
            esac
            ;;
        fsl)    ver=$(cat ${FSLDIR}/etc/fslversion) ;;
    esac

    jo -d. ${1}.version="${ver}" | jq -s add ${outfile} - > tmp.json
    mv tmp.json ${outfile}
}

# Log system information in a JSON file
#
# If you would like to add to an existing file, supply it as an argument.
# Otherwise, the information will be stored in "preproc.json".
#
# $1 - the JSON file to add to, if it exists
#
# Examples
#
#    log_system_info preproc.json
log_system_info() {
    if [[ $# -lt 1 ]]; then
        outfile=preproc.json
        if [[ ! -f ${outfile} ]]; then
            touch ${outfile}
        fi
    else
        outfile=${1}
    fi
    jo -d. system.system="$(uname)" \
        system.kernel.version="$(uname -v)" \
        system.kernel.release="$(uname -r)" \
        system.hardware="$(uname -m)" | \
        jq -s add ${outfile} - > tmp.json
    mv tmp.json ${outfile}
}

export myred mygreen myyellow
export -f check_sw log_sw_info log_system_info
