#! /bin/bash
# Chris Watson, 2016-2019
set -a
source $(dirname "${BASH_SOURCE[0]}")/globals.sh

usage() {
    cat << !

 "${mygreen}$(basename $0)$(tput sgr0)" performs the steps needed before running ${myblue}probtrackx2$(tput sgr0)
 with Freesurfer labels as seed and target regions. Specifically, the T1w and
 Freesurfer labels are registered to diffusion space using ${myblue}bbregister$(tput sgr0).

 ${myyellow}USAGE:${mygreen}
    $(basename $0) -s|--subject SUBJECT -a|--atlas ATLAS
        [--long SESSION] [--acq LABEL]

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

    ${mymagenta}--acq [ACQ LABEL]$(tput sgr0)
        If multiple acquisitions, provide the label. For example, the TBI study
        acquired 2 DTI scans; the acq label for the TBI study would be ${myblue}iso$(tput sgr0):
            ${mygreen}sub-<subLabel>_ses-<sessLabel>_acq-iso_dwi.nii.gz

 ${myyellow}EXAMPLE:${mygreen}
    $(basename $0) -s SP7180 -a dkt.scgm --long 01 --acq iso

!
}

# Check arguments
#-------------------------------------------------------------------------------
[[ $# == 0 ]] && usage && exit

TEMP=$(getopt -o hs:a: --long help,subject:,atlas:,long:,acq: -- "$@")
[[ $? -ne 0 ]] && usage && exit 64
eval set -- "${TEMP}"

atlas=dk.scgm
long=0
sess=''
acq=''
while true; do
    case "$1" in
        -h|--help)      usage && exit ;;
        -s|--subject)   subj="$2"; shift ;;
        -a|--atlas)     atlas=$2; shift ;;
        --long)         long=1; sess="$2"; shift ;;
        --acq)          acq="$2"; shift ;;
        * )             break ;;
    esac
    shift
done

atlarray=(dk.scgm dkt.scgm destrieux.scgm)
[[ ! "${atlarray[@]}" =~ "${atlas}" ]] && echo -e "\nAtlas ${atlas} is invalid.\n" && exit 79
case "${atlas}" in
    destrieux.scgm) atlas_base="aparc.a2009s+aseg" ;;
    dkt.scgm)       atlas_base="aparc.DKTatlas40+aseg" ;;
    dk.scgm)        atlas_base="aparc+aseg" ;;
esac

source $(dirname "${BASH_SOURCE[0]}")/setup_vars.sh

# Set directory variables
#-------------------------------------------------------------------------------
SUBJECTS_DIR=${projdir}/freesurfer
fs_mri_dir=${SUBJECTS_DIR}/${fs_sub_dir}/mri
regdir=${projdir}/${resdir}/registrations
xfmdir=${regdir}/xfms
seed_dir=${resdir}.probtrackX2/seeds/${atlas}

mkdir -p ${regdir}/{anat,fs,diff,xfms}

# If the parc + seg volume doesn't exist, create it
if [[ ! -e "${fs_mri_dir}/${atlas_base}.mgz" ]]; then
    ${FREESURFER_HOME}/bin/mri_aparc2aseg --s ${fs_sub_dir} --annot ${atlas_base%+aseg}
fi
${FREESURFER_HOME}/bin/mri_convert ${fs_mri_dir}/${atlas_base}.mgz ${regdir}/fs/${atlas_base}.nii.gz

# Do the registrations and get all of the transformation matrices
#-------------------------------------------------------------------------------
# Change orientation for FSL
${FREESURFER_HOME}/bin/mri_convert ${fs_mri_dir}/brain.mgz ${regdir}/fs/brain.nii.gz
${FREESURFER_HOME}/bin/flip4fsl ${regdir}/fs/brain.nii.gz ${regdir}/anat/brain.nii.gz

# Calc. reg. from FS conformed to flipped anatomical (FSL) space
${FREESURFER_HOME}/bin/tkregister2 --mov ${regdir}/fs/brain.nii.gz \
    --targ ${regdir}/anat/brain.nii.gz \
    --regheader --noedit \
    --fslregout ${xfmdir}/fs2anat.mat --reg ${xfmdir}/anat2fs.dat
${FSLDIR}/bin/convert_xfm -omat ${xfmdir}/anat2fs.mat -inverse ${xfmdir}/fs2anat.mat

# Register diffusion to FS conformed space
${FREESURFER_HOME}/bin/bbregister --s ${fs_sub_dir} --init-fsl --dti --mov ${resdir}/data.nii.gz \
    --reg ${xfmdir}/fs2diff.bbr.dat --fslmat ${xfmdir}/diff2fs.bbr.mat
${FSLDIR}/bin/convert_xfm -omat ${xfmdir}/fs2diff.bbr.mat -inverse ${xfmdir}/diff2fs.bbr.mat

# Calc. flipped anatomical to low-b
${FSLDIR}/bin/convert_xfm -omat ${xfmdir}/anat2diff.bbr.mat \
    -concat ${xfmdir}/fs2diff.bbr.mat ${xfmdir}/anat2fs.mat
${FSLDIR}/bin/convert_xfm -omat ${xfmdir}/diff2anat.bbr.mat -inverse ${xfmdir}/anat2diff.bbr.mat

# Apply transform to the parcellation (e.g., "aparc+aseg") volume
# FS conformed --> diffusion space
#-------------------------------------------------------------------------------
# Change orientation to make FSL happy
flip4fsl ${regdir}/fs/${atlas_base}.nii.gz ${regdir}/anat/${atlas_base}.nii.gz
flirt -in ${regdir}/anat/${atlas_base}.nii.gz -ref ${resdir}/nodif.nii.gz \
    -out ${regdir}/diff/${atlas_base}.bbr.nii.gz \
    -applyxfm -init ${xfmdir}/anat2diff.bbr.mat \
    -interp nearestneighbour

# Map diffusion brain mask to FS conformed space
flirt -in ${resdir}/nodif_brain_mask.nii.gz -ref ${regdir}/fs/brain.nii.gz \
    -out ${regdir}/fs/nodif_brain_mask.bbr.nii.gz \
    -applyxfm -init ${xfmdir}/diff2fs.bbr.mat \
    -interp nearestneighbour

# Extract the individual cortical and subcortical labels
#-------------------------------------------------------------------------------
labelfile=${scriptdir}/../atlases/${atlas}.txt
[[ ! -e ${labelfile} ]] && echo "Label file '${labelfile}' missing." && exit 80
mkdir -p ${seed_dir} && cd ${seed_dir}
while read line; do
    roiID=$(echo ${line} | awk '{print $1}' -)
    roiNAME=$(echo ${line} | awk '{print $2}' -)
    fslmaths \
        ${regdir}/diff/${atlas_base}.bbr \
        -thr ${roiID} -uthr ${roiID} \
        -bin ${roiNAME}
    fslstats ${roiNAME} -V | awk '{print $1}' >> sizes.txt
done < ${labelfile}

echo ${PWD}/*.nii.gz | tr " " "\n" >> seeds.txt
paste sizes.txt seeds.txt | sort -k1 -nr - | awk '{print $2}' - >> seeds_sorted.txt

# Ventricles mask
mri_binarize --i ${regdir}/diff/${atlas_base}.bbr.nii.gz --ventricles --o ventricles.nii.gz
