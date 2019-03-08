#! /bin/bash
# Chris Watson, 2018-08-09

usage() {
    cat << !

 Export some directory- and filename-related variables for DTI preprocessing,
 analysis, etc. using FSL tools.

 Filename strings differ for different modalities. For example, in a theoretical
 test-retest study, for subject "s001",

    sub-s001_ses-retest_acq-highres_T1w.nii.gz
    sub-s001_ses-retest_acq-multiband_dir-AP_dwi.nii.gz
    sub-s001_ses-retest_acq-multiband_dir-PA_dwi.nii.gz
    sub-s001_ses-retest_task-rest_bold.nii.gz

!
}

if [[ -z ${scriptdir} ]]; then
    scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
fi
source ${scriptdir}/check_dependencies.sh

# Figure out some modality-specific labels, if ${modality} is provided
# If none is provided, "dwi" is chosen
#-------------------------------------------------------------------------------
mod_dir=dwi
mod=dwi
if [[ ! -z ${modality} ]]; then
    case "${modality}" in
        [Tt]1|[Tt]1[Ww])            mod_dir=anat; mod=T1w ;;
        [Dd][TtWw][Ii]|diff)        mod_dir=dwi; mod=dwi ;;
        rest|[Ff][Mmu][Rrn][Iic])   mod_dir=func; mod=bold ;;
    esac
fi

projdir=${PWD}
target=sub-${subj}
rawdir=rawdata/${target}/
if [[ ${long} -eq 1 ]]; then
    target=${target}_ses-${sess}
    rawdir=${rawdir}/ses-${sess}
fi

# fmri data have a "task" label in the filename
#---------------------------------------
if [[ ${mod_dir} == func ]]; then
    target=${target}_task-rest
fi

if [[ ! -z ${acq} ]]; then
    target=${target}_acq-${acq}_${mod}
else
    target=${target}_${mod}
fi
rawdir=${rawdir}/${mod_dir}
srcdir=${rawdir/rawdata/sourcedata}
resdir=${rawdir/rawdata/tractography}

[[ ! -d ${srcdir} ]] && mkdir -p ${srcdir}

export projdir target rawdir srcdir resdir scriptdir
