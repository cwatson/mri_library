#! /bin/bash
#
# Calculate the mean FA/MD/etc. for all tracts after a probtrackx2 run
#_______________________________________________________________________________
# Chris Watson, 2016-10-20
set -a
source $(dirname "${BASH_SOURCE[0]}")/globals.sh

usage() {
    cat << !

 "${mygreen}$(basename $0)$(tput sgr0)" calculates the mean value of some
 microstructural measure (FA, MD, etc.) for all between-region pairs from the
 results of ${myblue}probtrackx2$(tput sgr0) using Freesurfer labels as seed and target
 regions. The ${myblue}fdt_paths$(tput sgr0) are first thresholded proportionally (at a
 default level of 0.9, keeping only the top 10%); this is then used as a mask to
 calculate the mean (by default, of FA).

 ${myyellow}USAGE:${mygreen}
    $(basename $0) -s|--subject SUBJECT -a|--atlas ATLAS
        [-m|--measure MEASURE] [-t|--threshold PTHRESH]
        [--long SESSION] [--acq LABEL]

 ${myyellow}OPTIONS:
    ${mymagenta}-h, --help$(tput sgr0)
        Show this message

    ${mymagenta}-s, --subject [SUBJECT]$(tput sgr0)
        Subject ID. This will be the "label" in the directories and filenames,
        as outlined by the BIDS spec

    ${mymagenta}-a, --atlas [ATLAS]$(tput sgr0)
        The atlas name (either ${myblue}dk.scgm$(tput sgr0), ${myblue}dkt.scgm$(tput sgr0), or ${myblue}destrieux.scgm$(tput sgr0))
        ${myyellow}Default: dk.scgm$(tput sgr0)

    ${mymagenta}-m, --measure [MEASURE]$(tput sgr0)
        The microstructural measure to use (FA, MD, AD, RD). These are calculated
        from the ${myblue}dtifit$(tput sgr0) outputs.
        ${myyellow}Default: FA

    ${mymagenta}-t, --threshold [PTHRESH]$(tput sgr0)
        The proportional threshold applied to ${myblue}fdt_paths.nii.gz$(tput sgr0) for
        creating a mask of the "tract". So for the default of 0.9, the top 10%
        of streamlines are kept.
        ${myyellow}Default: 0.9

    ${mymagenta}--long [SESSION]$(tput sgr0)
        If it's a longitudinal study, specify the session label.

    ${mymagenta}--acq [ACQ LABEL]$(tput sgr0)
        If multiple acquisitions, provide the label. For example, the TBI study
        acquired 2 DTI scans; the acq label for the TBI study would be ${myblue}iso$(tput sgr0):
            ${mygreen}sub-<subLabel>_ses-<sessLabel>_acq-iso_dwi.nii.gz

    ${mymagenta}--pd$(tput sgr0)
        If you ran tractography with the ${myblue}--pd$(tput sgr0) option, specify here.

 ${myyellow}EXAMPLE:${mygreen}
    $(basename $0) -s SP7180 -a dkt.scgm -m RD -p 0.95 --long 01 --acq iso

!
exit
}

# Check arguments
#-------------------------------------------------------------------------------
[[ $# == 0 ]] && usage && exit

TEMP=$(getopt -o hs:a:n:m:t: --long help,subject:,atlas:,measure:,threshold:,long:,acq:,pd -- "$@")
[[ $? -ne 0 ]] && usage && exit 64
eval set -- "${TEMP}"

atlas=dk.scgm
long=0
sess=''
acq=''
measure=FA
thresh=0.9
do_pd=0
while true; do
    case "$1" in
        -h|--help)      usage && exit ;;
        -s|--subject)   subj="$2"; shift ;;
        -a|--atlas)     atlas=$2; shift ;;
        -m|--measure)   measure=$2; shift ;;
        -t|--threshold) thresh=$2; shift ;;
        --long)         long=1; sess="$2"; shift ;;
        --acq)          acq="$2"; shift ;;
        --pd)           do_pd=1; shift ;;
        * )             break ;;
    esac
    shift
done

source $(dirname "${BASH_SOURCE[0]}")/setup_vars.sh

# Figure out where ptx results are
#---------------------------------------
if [[ ${do_pd} -eq 1 ]]; then
    ptxdir=${projdir}/${resdir}.probtrackX2/results_pd/${atlas}
else
    ptxdir=${projdir}/${resdir}.probtrackX2/results_noPd/${atlas}
fi
measure_im=${projdir}/${resdir}/dtifit/dtifit_${measure}
matfile=${ptxdir}/W_${measure}_${thresh}.txt

cd ${ptxdir}
for seed in [12]*; do
    cd ${seed}
    for target in target_paths*.nii.gz; do
        fslmaths ${target} -thrp ${thresh} targmask
        if [[ $(fslstats targmask -V | awk '{print $1}') -eq 0 ]]; then
            echo -n "0 " >> ${matfile}
        else
            echo -n "$(fslstats ${measure_im} -k targmask -M) " >> ${matfile}
        fi
    done
    cd -
    echo >> ${matfile}
done
