#! /bin/bash
#_______________________________________________________________________________
# updated 2018-08-12 to work w/ BIDS-structured data on Stampede2
# updated 2017-03-27
# Chris Watson, 2016-01-11
set -a
source $(dirname "${BASH_SOURCE[0]}")/globals.sh

usage() {
    cat << !

 Performs the steps needed before running ${myblue}probtrackx2$(tput sgr0) with Freesurfer labels:
     1. Generate a NIfTI ${myblue}aparc+aseg$(tput sgr0) file (if needed)
     2. Register the anatomical (T1) volume to diffusion space (via ${myblue}TRACULA$(tput sgr0)).

 ${myyellow}USAGE:${mygreen}
    $(basename $0) -s|--subject SUBJECT -a|--atlas ATLAS [--rerun]
        [--long SESSION] [--acq LABEL]

 ${myyellow}OPTIONS:
    ${mymagenta}-h, --help$(tput sgr0)
        Show this message

    ${mymagenta}-s, --subject [SUBJECT]$(tput sgr0)
        Subject ID. This will be the "label" in the directories and filenames,
        as outlined by the BIDS spec

    ${mymagenta}-a, --atlas [ATLAS]$(tput sgr0)
        The atlas name (either ${myblue}dk.scgm$(tput sgr0), ${myblue}dkt.scgm$(tput sgr0), or ${myblue}destrieux.scgm$(tput sgr0))

    ${mymagenta}--long [SESSION]$(tput sgr0)
        If it's a longitudinal study, specify the session label.

    ${mymagenta}--acq [ACQ LABEL]$(tput sgr0)
        If multiple acquisitions, provide the label. For example, the TBI study
        acquired 2 DTI scans; the acq label for the TBI study would be ${myblue}iso$(tput sgr0):
            ${mygreen}sub-<subLabel>_ses-<sessLabel>_acq-iso_dwi.nii.gz

    ${mymagenta}--rerun$(tput sgr0)
        Include if you want to re-run the registration steps

 ${myyellow}EXAMPLE:${mygreen}
    $(basename $0) -s SP7180 --long 01 --acq iso

!
}

# Check arguments
#-------------------------------------------------------------------------------
[[ $# == 0 ]] && usage && exit

TEMP=$(getopt -o hs:a: --long help,subject:,atlas:,long:,acq:,rerun -- "$@")
[[ $? -ne 0 ]] && usage && exit 1
eval set -- "${TEMP}"

long=0
sess=''
acq=''
rerun=0
while true; do
    case "$1" in
        -h|--help)      usage && exit ;;
        -s|--subject)   subj="$2"; shift ;;
        -a|--atlas)     atlas=$2; shift ;;
        --long)         long=1; sess="$2"; shift ;;
        --acq)          acq="$2"; shift ;;
        --rerun)        rerun=1; shift ;;
        * )             break ;;
    esac
    shift
done

atlarray=(dk.scgm dkt.scgm destrieux.scgm)
[[ ! "${atlarray[@]}" =~ "${atlas}" ]] && echo -e "\nAtlas ${atlas} is invalid.\n" && exit 13

source $(dirname "${BASH_SOURCE[0]}")/dti_vars.sh

# Set directory variables
#-------------------------------------------------------------------------------
dti_dir=${projdir}/${resdir}
SUBJECTS_DIR=${projdir}/freesurfer

[[ ! -d ${dti_dir} ]] && echo "Subject directory ${dti_dir} is invalid." && exit 14
ln ${dti_dir}/{nodif.nii.gz,lowb.nii.gz}
ln ${dti_dir}/{nodif_brain_mask.nii.gz,lowb_brain_mask.nii.gz}

mkdir -p ${SUBJECTS_DIR}/${subj}/{dmri,dlabel/{anatorig,diff}}
fs_dti_dir=${SUBJECTS_DIR}/${subj}/dmri
fs_label_dir=${SUBJECTS_DIR}/${subj}/dlabel

seed_dir=${dti_dir}.probtrackX2/seeds/${atlas}
mri_dir=${SUBJECTS_DIR}/${subj}/mri

if [[ ${atlas} == 'destrieux.scgm' ]]; then
    atlas_base="aparc.a2009s+aseg"
elif [[ ${atlas} == 'dk.scgm' ]]; then
    atlas_base="aparc+aseg"
elif [[ ${atlas} == 'dkt.scgm' ]]; then
    atlas_base="aparc.DKTatlas40+aseg"
fi
atlas_image="${fs_label_dir}/anatorig/${atlas_base}.nii.gz"

[[ ! -e "${mri_dir}/${atlas_base}.mgz" ]] && mri_aparc2aseg --s ${subj} --annot ${atlas_base%+aseg}
if  [[ ! -e ${fs_label_dir}/anatorig/${atlas_base}.nii.gz ]]; then
    if [[ ! -e ${mri_dir}/${atlas_base}.nii.gz ]]; then
        mri_convert ${mri_dir}/${atlas_base}.{mgz,nii.gz}
    fi
    mv ${mri_dir}/${atlas_base}.nii.gz ${fs_label_dir}/anatorig/
fi

#-------------------------------------------------------------------------------
# Check if the transforms from Tracula exist; if not, create them
#-------------------------------------------------------------------------------
if [[ ! -e ${SUBJECTS_DIR}/${subj}/dmri/xfms/anatorig2diff.bbr.mat ]]; then
    ln ${dti_dir}/data.nii.gz ${fs_dti_dir}/dwi.nii.gz
    ln ${dti_dir}/{bvals,bvecs,lowb.nii.gz,lowb_brain_mask.nii.gz} ${fs_dti_dir}/
    ln ${dti_dir}/lowb_brain_mask.nii.gz ${fs_label_dir}/diff

    for meas in FA MD L1 L2 L3; do
        ln ${dti_dir}/dtifit/*_${meas}.nii.gz ${fs_dti_dir}/dtifit_${meas}.nii.gz
    done

    # Run the remaining steps of trac-all -prep
    trac_config=${SUBJECTS_DIR}/dmrirc/dmrirc.${subj}
    if [[ ! -e ${trac_config} ]]; then
        cp ${FREESURFER_HOME}/bin/dmrirc.example ${trac_config}
        sed -i "s:/path/to/recons/of/ducks:${SUBJECTS_DIR}:" ${trac_config}
        sed -i "s:/path/to/tracts/of/ducks:${SUBJECTS_DIR}:" ${trac_config}
        sed -i "s/(huey dewey louie)/${subj}/" ${trac_config}
        sed -i 's/(1 3)/1/' ${trac_config}
        sed -i 's:(huey/day1.*::' ${trac_config}
        sed -i '64,66d' ${trac_config}
        sed -i "s:/path/to/bvecs.txt:${fs_dti_dir}/bvecs:" ${trac_config}
        sed -i "s:/path/to/bvals.txt:${fs_dti_dir}/bvals:" ${trac_config}
        sed -i '/dob0/s:1:0:' ${trac_config}
        sed -i '/dcmroot/s:^:#:' ${trac_config}
        sed -i '/b0.*list/s:^:#:' ${trac_config}
        sed -i '/echospacing/s:^:#:' ${trac_config}
        sed -i '/thrbet/s:^:#:' ${trac_config}
        sed -i '/cvstemp*/s:^:#:' ${trac_config}
    fi
    trac-all -c ${trac_config} -intra -masks
fi

if [[ ${atlas} == 'dkt.scgm' ]] || [[ ${atlas} == 'destrieux.scgm' ]]; then
    flirt -in ${atlas_image} -ref ${fs_dti_dir}/lowb \
        -out ${fs_label_dir}/diff/${atlas_base}.bbr \
        -applyxfm -init ${fs_dti_dir}/xfms/anatorig2diff.bbr.mat \
        -interp nearestneighbour
fi
#-------------------------------------------------------------------------------

labelfile=${scriptdir}/../atlases/${atlas}.txt
[[ ! -e ${labelfile} ]] && echo "Label file '${labelfile}' missing." && exit 15
mkdir -p ${seed_dir} && cd ${seed_dir}
while read line; do
    roiID=$(echo ${line} | awk '{print $1}' -)
    roiNAME=$(echo ${line} | awk '{print $2}' -)
    fslmaths \
        ${fs_label_dir}/diff/${atlas_base}.bbr \
        -thr ${roiID} -uthr ${roiID} \
        -bin ${roiNAME}
    fslstats ${roiNAME} -V | awk '{print $1}' >> sizes.txt
done < ${labelfile}

echo ${PWD}/*.nii.gz | tr " " "\n" >> seeds.txt
paste sizes.txt seeds.txt | sort -k1 -nr - | awk '{print $2}' - >> seeds_sorted.txt

# Ventricles mask
mri_binarize --i ${fs_label_dir}/diff/${atlas_base}.bbr.nii.gz \
    --ventricles --o ventricles.nii.gz
cd ${projdir}
