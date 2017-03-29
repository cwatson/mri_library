#! /bin/bash
#
# Perform all the necessary steps for running "probtrackx2" using Freesurfer
# labels.
#_______________________________________________________________________________
# updated 2017-03-27
# Chris Watson, 2016-01-11

usage() {
    cat << !
    usage: $(basename $0) [options]

    This script will perform the necessary steps needed before running
    "probtrackx2" with Freesurfer labels.

    OPTIONS:
        -h          Show this message
        -a          Atlas (either 'dk.scgm', 'dkt.scgm', or 'destrieux.scgm')
        -p          Project name
        -g          Subject group
        -s          Subject name/ID
        --scanner   Scanner (either 1.5T or 3T)
        --rerun     Include if you would like to re-run registrations

    EXAMPLES:
        $(basename $0) -p CCFA -g case -s cd001 --rerun
        $(basename $0) -p Fontan -g control -s 02-430-4 --scanner 1.5T
!
}

# Check arguments
#-------------------------------------------------------------------------------
[[ $# == 0 ]] && usage && exit

TEMP=$(getopt -o ha:p:g:s: --long scanner:,rerun -- "$@")
[[ $? -ne 0 ]] && usage && exit 1
eval set -- "${TEMP}"

rerun=0
while true; do
    case "$1" in
        -h)         usage && exit ;;
        -a)         atlas=$2; shift ;;
        -g)         group=$2; shift ;;
        -s)         subj=$2; shift ;;
        -p)         proj=$2; shift ;;
        --scanner)  scanner=$2; shift ;;
        --rerun)    rerun=1; shift ;;
        * )         break ;;
    esac
    shift
done

[[ -z ${subj} ]] && echo "Must provide a subject ID!" && exit 2

atlarray=(dk.scgm dkt.scgm destrieux.scgm)
if [[ ! "${atlarray[@]}" =~ "${atlas}" ]]; then
    echo -e "\nAtlas is invalid!\n" && exit 3
fi

# Set directory variables
#-------------------------------------------------------------------------------
if [[ ${proj} == 'TBI' ]]; then
    scanner=''
    group=''
    base_dir=${WORK}/stress_study
    dti_dir=${base_dir}/dti/${subj}/dti2
    export SUBJECTS_DIR=${base_dir}/vol
    [[ ! -d ${dti_dir} ]] && echo "Subject/group name invalid!" && exit 4
    ln -s ${dti_dir}/{nodif.nii.gz,lowb.nii.gz}
    ln -s ${dti_dir}/{nodif_brain_mask.nii.gz,lowb_brain_mask.nii.gz}
else
    if [[ ${proj} == 'CCFA' ]]; then
        scanner=''
        base_dir='/raid2/fmri8/ibd/ccfa'
    elif [[ ${proj} == 'Fontan' ]]; then
        base_dir='/raid2/fmri8/fontan'
    else
        echo "Project name invalid!" && exit 5
    fi
    dti_dir=${base_dir}/dti/${scanner}/${group}/${subj}
    [[ ! -d ${dti_dir} ]] && echo "Subject/group/scanner invalid!" && exit 4
    export SUBJECTS_DIR=${base_dir}/volumetric/freesurfer/${scanner}/${group}
fi

if [[ ${rerun} -eq 1 ]]; then
    mkdir ${SUBJECTS_DIR}/${subj}/dti_old
    mv ${SUBJECTS_DIR}/${subj}/{dmri,dlabel} ${SUBJECTS_DIR}/${subj}/dti_old
fi
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
mri_convert ${mri_dir}/${atlas_base}.{mgz,nii.gz}
mv ${mri_dir}/${atlas_base}.nii.gz ${fs_label_dir}/anatorig/

#-------------------------------------------------------------------------------
# Check if the transforms from Tracula exist; if not, create them
#-------------------------------------------------------------------------------
if [ ! -e "${SUBJECTS_DIR}/${subj}/dmri/xfms/anatorig2diff.bbr.mat" ]; then
    ln -s ${dti_dir}/data.nii.gz ${fs_dti_dir}/dwi.nii.gz
    ln -s ${dti_dir}/{bvals,bvecs,lowb.nii.gz,lowb_brain_mask.nii.gz} ${fs_dti_dir}/
    ln -s ${dti_dir}/lowb_brain_mask.nii.gz ${fs_label_dir}/diff

    for meas in FA MD L1 L2 L3; do
        ln -s ${dti_dir}/dtifit/*_${meas}.nii.gz ${fs_dti_dir}/dtifit_${meas}.nii.gz
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

labelfile=${HOME}/Dropbox/dnl_library/bin/fsl/${atlas}.txt
[[ ! -e ${labelfile} ]] && echo "Label file missing!" && exit 6
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
cd ${base_dir}
