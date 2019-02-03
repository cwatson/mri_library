#! /bin/bash
#
# Run a different instance of probtrackx2 for all seeds, or in network mode.
#_______________________________________________________________________________
# updated 2017-03-28
# Chris Watson, 2016-11-02
set -a
source $(dirname "${BASH_SOURCE[0]}")/globals.sh

usage() {
    cat << !

 Run ${myblue}probtrackx2$(tput sgr0) w/ a separate process for each seed ROI, or if ${myblue}--network$(tput sgr0)
 is included, then in "network" mode. The GPU version is used unless ${myblue}--parallel$(tput sgr0)
 is included.

 ${myyellow}USAGE:${mygreen}
    $(basename $0) -s|--subject SUBJECT -a|--atlas ATLAS [--long SESSION]
        [--acq LABEL] [-P NUM_SAMPLES] [--parallel] [--network] [--pd]

 ${myyellow}OPTIONS:
    ${mymagenta}-h, --help$(tput sgr0)
        Show this message

    ${mymagenta}-a, --atlas$(tput sgr0)
        The atlas name (either ${myblue}dk.scgm$(tput sgr0), ${myblue}dkt.scgm$(tput sgr0), or ${myblue}destrieux.scgm$(tput sgr0))

    ${mymagenta}-s, --subject$(tput sgr0)
        Subject ID. This will be the "label" in the directories and filenames,
        as outlined by the BIDS spec

    ${mymagenta}--long [SESSION]$(tput sgr0)
        If it's a longitudinal study, specify the session label.

    ${mymagenta}--acq [ACQ LABEL]$(tput sgr0)
        If multiple acquisitions, provide the label. For example, the TBI study
        acquired 2 DTI scans; the acq label for the TBI study would be ${myblue}iso$(tput sgr0):
            ${mygreen}sub-<subLabel>_ses-<sessLabel>_acq-iso_dwi.nii.gz

    ${mymagenta}-P$(tput sgr0)
        Number of samples (default: 5000)

    ${mymagenta}--parallel$(tput sgr0)
        Include if you want to do in parallel (if not, the GPU version will be
        called as well)

    ${mymagenta}--network$(tput sgr0)
        Run in network mode (overrides ${myblue}--parallel$(tput sgr0))

    ${mymagenta}--pd$(tput sgr0)
        Run with the ${myblue}--pd$(tput sgr0) option

 ${myyellow}EXAMPLES:${mygreen}
    $(basename $0) -a dk.scgm -s SP7104_time1 -P 1000 --parallel
    $(basename $0) -a dkt.scgm -s cd001

!
}

# Argument checking
#-------------------------------------------------------------------------------
[[ $# == 0 ]] && usage && exit

TEMP=$(getopt -o hs:a:P: --long help,subject:,atlas:,long:,acq:,parallel,network,pd -- "$@")
[[ $? -ne 0 ]] && usage && exit 1
eval set -- "${TEMP}"

long=0
sess=''
acq=''
nSamples=5000
run_parallel=0
run_network=0
do_pd=0
while true; do
    case "$1" in
        -h|--help)      usage && exit ;;
        -s|--subject)   subj="$2"; shift ;;
        -a|--atlas)     atlas="$2"; shift ;;
        --long)         long=1; sess="$2"; shift ;;
        --acq)          acq="$2"; shift ;;
        -P)             nSamples="$2"; shift ;;
        --parallel)     run_parallel=1 ;;
        --network)      run_network=1 ;;
        --pd)           do_pd=1 ;;
        * )             break ;;
    esac
    shift
done

atlarray=(dk.scgm dkt.scgm destrieux.scgm)
[[ ! "${atlarray[@]}" =~ "${atlas}" ]] && echo -e "\nAtlas ${atlas} is invalid.\n" && exit 12

source $(dirname "${BASH_SOURCE[0]}")/dti_vars.sh
bpx_dir=${projdir}/${resdir}.bedpostX
seed_dir=${projdir}/${resdir}.probtrackX2/seeds/${atlas}
seed_file=${seed_dir}/seeds_sorted.txt
ptx_dir=${subj}.probtrackX2/results/${atlas}

#-----------------------------------------------------------
# Run in parallel with regular ptx2, or not with GPU version
#-----------------------------------------------------------
if [[ ${run_parallel} -eq 1 ]]; then
    while read line; do
        sem -j+0 probtrackx2 \
            -x ${line} \
            -s ${bpx_dir}/merged \
            -m ${bpx_dir}/nodif_brain_mask \
            -P ${nSamples} \
            --omatrix1 \
            --os2t \
            --otargetpaths \
            --s2tastext \
            --forcedir \
            --opd \
            --avoid=${seed_dir}/ventricles.nii.gz \
            --dir=${ptx_dir}/$(basename ${line} .nii.gz) \
            --targetmasks=${seed_file}
    done < ${seed_file}
else
    if [[ ${run_network} -eq 0 ]]; then
        while read line; do
            probtrackx2_gpu \
                -x ${line} \
                -s ${bpx_dir}/merged \
                -m ${bpx_dir}/nodif_brain_mask \
                -P ${nSamples} \
                --omatrix1 \
                --os2t \
                --otargetpaths \
                --s2tastext \
                --forcedir \
                --opd \
                --avoid=${seed_dir}/ventricles.nii.gz \
                --dir=${ptx_dir}/$(basename ${line} .nii.gz) \
                --targetmasks=${seed_file}
        done < ${seed_file}
    else
        # Don't run in parallel, and run in "--network" mode
        #TODO should I include "--omatrix1" and others?
        probtrackx2_gpu \
            --network \
            -x ${seed_dir}/seeds.txt \
            -s ${bpx_dir}/merged \
            -m ${bpx_dir}/nodif_brain_mask \
            -P ${nSamples} \
            --forcedir \
            --opd \
            --avoid=${seed_dir}/ventricles.nii.gz \
            --dir=${ptx_dir}/network.gpu/
    fi
fi
