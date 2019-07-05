#! /bin/bash
# Chris Watson, 2016-2019
set -a
source $(dirname "${BASH_SOURCE[0]}")/globals.sh

usage() {
    cat << !

 "${mygreen}$(basename $0)$(tput sgr0)" combines the results from ${myblue}probtrackx2$(tput sgr0),
 specifically the "${myblue}matrix_seeds_to_all_targets$(tput sgr0)" files, into a single matrix and
 re-orders the rows and columns to match the alphanumeric ordering of seed and
 target regions.

 ${myyellow}USAGE:${mygreen}
    $(basename $0) -s|--subject SUBJECT -a|--atlas ATLAS
        [--long SESSION] [-P NUM_SAMPLES] [--pd]

 ${myyellow}OPTIONS:
    ${mymagenta}-h, --help$(tput sgr0)
        Show this message

    ${mymagenta}-s, --subject [SUBJECT]$(tput sgr0)
        Subject ID. This will be the "label" in the directories and filenames,
        as outlined by the BIDS spec

    ${mymagenta}-a, --atlas [ATLAS]$(tput sgr0)
        The atlas name (either ${myblue}dk.scgm$(tput sgr0), ${myblue}dkt.scgm$(tput sgr0), or ${myblue}destrieux.scgm$(tput sgr0))
        Default: ${myblue}dk.scgm$(tput sgr0)

    ${mymagenta}--long [SESSION]$(tput sgr0)
        If it's a longitudinal study, specify the session label.

    ${mymagenta}-P$(tput sgr0)
        Number of samples (default: 5000)

    ${mymagenta}--pd$(tput sgr0)
        Run with the ${myblue}--pd$(tput sgr0) option

 ${myyellow}EXAMPLE:${mygreen}
    $(basename $0) -s SP7180 -a dk.scgm --long 01 --pd

!
}

# Check arguments
#-------------------------------------------------------------------------------
[[ $# == 0 ]] && usage && exit

TEMP=$(getopt -o hs:a:P: --long help,subject:,atlas:,long:,pd -- "$@")
[[ $? -ne 0 ]] && usage && exit 64
eval set -- "${TEMP}"

atlas=dk.scgm
long=0
sess=''
nSamples=5000
do_pd=0
while true; do
    case "$1" in
        -h|--help)      usage && exit ;;
        -s|--subject)   subj="$2"; shift ;;
        -a|--atlas)     atlas=$2; shift ;;
        --long)         long=1; sess="$2"; shift ;;
        -P)             nSamples="$2"; shift ;;
        --pd)           do_pd=1 ;;
        *)              break ;;
    esac
    shift
done

atlarray=(dk.scgm dkt.scgm destrieux.scgm)
[[ ! "${atlarray[@]}" =~ "${atlas}" ]] && echo -e "\nAtlas ${atlas} is invalid.\n" && exit 79

source $(dirname "${BASH_SOURCE[0]}")/setup_vars.sh
seed_file=${projdir}/${resdir}.probtrackX2/seeds/${atlas}/seeds_sorted.txt
if [[ ${do_pd} -eq 1 ]]; then
    ptx_dir=${resdir}.probtrackX2/results_pd/${atlas}
else
    ptx_dir=${resdir}.probtrackX2/results_noPd/${atlas}
fi

R -e "source(\"${scriptdir}/../R/fsl_fdt_matrix.R\"); fsl_fdt_matrix(\"${ptx_dir}\", ${nSamples}, \"${seed_file}\")"
