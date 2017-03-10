#! /bin/bash
#
# Perform all the necessary steps for running "probtrackx2" using AAL90 labels.
#_______________________________________________________________________________
# Chris Watson, 2016-01-11

usage()
{
    cat << !
    usage: $(basename $0) [options]

    This script will perform the necessary steps needed before running
    "probtrackx2" using AAL90 labels.

    OPTIONS:
        -h          Show this message
        -a          Atlas (either 'dkt.scgm' or 'destrieux.scgm')
        -p          Project name (e.g. Fontan)
        -g          Subject group
        -s          Subject name/ID
        --scanner   Scanner (either 1.5T or 3T)

    EXAMPLES:
        $(basename $0) -p CCFA -g case -s cd001
        $(basename $0)
            -p Fontan
            -g control
            -s 02-430-4
            --scanner 1.5T
!
}

# Check arguments
#-------------------------------------------------------------------------------
if [ $# == 0 ]
then
    usage
    exit 1
fi

while :
do
    case $1 in
        -h)
            usage
            exit 1
            ;;

        -a)
            if [ -n "$2" ]
            then
                atlas=$2
                shift
            else
                echo -e "\nOption \"$1\" requires an argument\n"
                exit 2
            fi
            ;;

        -g)
            if [ -n "$2" ]
            then
                group=$2
                shift
            else
                echo -e "\nOption \"$1\" requires an argument\n"
                exit 2
            fi
            ;;

        -s)
            if [ -n "$2" ]
            then
                subj=$2
                shift
            else
                echo -e "\nOption \"$1\" requires an argument\n"
                exit 2
            fi
            ;;

        -p)
            if [ -n "$2" ]
            then
                proj=$2
                shift
            else
                echo -e "\nOption \"$1\" requires an argument\n"
                exit 2
            fi
            ;;

        --scanner)
            if [ -n "$2" ]
            then
                scanner=$2
                shift
            else
                echo -e "\nOption \"$1\" requires an argument\n"
                exit 2
            fi
            ;;

        *)
            break
            ;;
    esac

    shift
done

if [[ -z ${group} ]]; then
    echo "Must provide a group name!"
    exit 3
fi
if [[ -z ${subj} ]]; then
    echo "Must provide a subject ID!"
    exit 4
fi
if [[ -z ${proj} ]]; then
    echo "Must provide a project name!"
    exit 5
fi

# Set directory variables
#-------------------------------------------------------------------------------
if [[ ${proj} == 'CCFA' ]]; then
    scanner=''
    base_dir='/raid2/fmri8/ibd/ccfa'
else
    if [[ -z ${scanner} ]]; then
        echo "Must provide a scanner (1.5T or 3T)!"
        exit 6
    fi
    base_dir='/raid2/fmri8/fontan'
fi
dti_dir=${base_dir}/dti/${scanner}/${group}/${subj}
SUBJECTS_DIR=${base_dir}/volumetric/freesurfer/${scanner}/${group}
seed_dir=${dti_dir}.probtrackX2/seeds/${atlas}
aparc_dir=${dti_dir}/struct/
mri_dir=${SUBJECTS_DIR}/${subj}/mri
mkdir -p ${aparc_dir} ${seed_dir}

if [[ ${atlas} == 'dkt.scgm' ]]; then
    atlas_base="aparc.DKTatlas40+aseg"
    atlas_image="${aparc_dir}/${atlas_base}.nii.gz"
    if [ ! -e "${atlas_image}" ]; then
        if [ ! -e "${mri_dir}/${atlas_base}.mgz" ]; then
            mri_aparc2aseg --s ${subj} --annot aparc.DKTatlas40
        fi
        mri_convert ${mri_dir}/${atlas_base}.{mgz,nii.gz}
        mv ${mri_dir}/${atlas_base}.nii.gz ${aparc_dir}
    fi
elif [[ ${atlas} == 'destrieux.scgm' ]]; then
    atlas_image="${aparc_dir}/aparc.a2009s+aseg.nii.gz"
    if [ ! -e "${atlas_image}" ]; then
        mri_convert ${mri_dir}/aparc.a2009s+aseg.{mgz,nii.gz}
        mv ${mri_dir}/aparc.a2009s+aseg.nii.gz ${aparc_dir}
    fi
else
    echo "Invalid atlas! Choose 'dkt.scgm' or 'destrieux.scgm'"
    exit 4
fi

cd ${aparc_dir}
if [ ! -e "${aparc_dir}/norm.nii.gz" ]; then
    mri_convert ${mri_dir}/norm.mgz ${aparc_dir}/norm.nii.gz
    bet2 norm struct_brain -m -f 0.35
fi
if [ ! -e "${aparc_dir}/struct2dwi.nii.gz" ]; then
    echo -e "\n==========================================================="
    echo -e "Registering 'norm' to DWI space"
    echo -e "==========================================================="
    flirt -in struct_brain -ref ../dwi -out struct2dwi
fi

#-------------------------------------------------------------------------------
# Check if the transforms from Tracula exist; if not, create them
#-------------------------------------------------------------------------------
if [ ! -e "${SUBJECTS_DIR}/${subj}/dmri/xfms/anatorig2diff.bbr.mat" ]; then
    mkdir -p ${SUBJECTS_DIR}/${subj}/{dmri,dlabel/diff}
    fs_dti_dir=${SUBJECTS_DIR}/${subj}/dmri
    ln -s ${dti_dir}/{dwi_orig.nii.gz,dwi.nii.gz,dwi.ecclog} ${fs_dti_dir}/
    ln -s ${fs_dti_dir}/dwi_orig.nii.gz ${fs_dti_dir}/dwi_orig_flip.nii.gz
    ln -s ${fs_dti_dir}/dwi.nii.gz ${fs_dti_dir}/data.nii.gz
    ln -s ${SUBJECTS_DIR}/bvecs_transpose ${fs_dti_dir}/dwi_orig.mghdti.bvecs
    ln -s ${SUBJECTS_DIR}/bvals_transpose ${fs_dti_dir}/dwi_orig.mghdti.bvals
    ln -s ${dti_dir}/{bvals,bvecs,lowb.nii.gz,lowb_brain.nii.gz} ${fs_dti_dir}/
    ln -s ${dti_dir}/lowb_brain_mask.nii.gz ${SUBJECTS_DIR}/${subj}/dlabel/diff

    for meas in FA MD L1 L2 L3; do
        ln -s ${dti_dir}/dtifit/${subj}_dtifit_${meas}.nii.gz \
            ${fs_dti_dir}/dtifit_${meas}.nii.gz
    done

    # Run the remaining steps of trac-all -prep
    tracula_config=${SUBJECTS_DIR}/dmrirc/dmrirc.${subj}
    cp ${FREESURFER_HOME}/bin/dmrirc.example ${tracula_config}
    sed -i "s:/path/to/recons/of/ducks:${SUBJECTS_DIR}:" ${tracula_config}
    sed -i "s:/path/to/tracts/of/ducks:${SUBJECTS_DIR}:" ${tracula_config}
    sed -i "s/(huey dewey louie)/${subj}/" ${tracula_config}
    sed -i 's/(1 3)/1/' ${tracula_config}
    sed -i "s:/path/to/dicoms/of/ducks:${dti_dir}/archives:" ${tracula_config}
    sed -i 's:(huey/day1.*::' ${tracula_config}
    sed -i '64,66d' ${tracula_config}
    sed -i "s:/path/to/bvecs.txt:${SUBJECTS_DIR}/bvecs_transpose:" ${tracula_config}
    sed -i "s:/path/to/bvals.txt:${SUBJECTS_DIR}/bvals_transpose:" ${tracula_config}
    sed -i '/dob0/s:1:0:' ${tracula_config}
    sed -i '/dcmroot/s:^:#:' ${tracula_config}
    sed -i '/b0mlist/s:^:#:' ${tracula_config}
    sed -i '/b0plist/s:^:#:' ${tracula_config}
    sed -i '/echospacing/s:^:#:' ${tracula_config}
    sed -i '/thrbet/s:^:#:' ${tracula_config}
    sed -i 's:/path/to/mni_template:/parietal/fsl/current/data/standard/MNI152_T1_1mm_brain:' \
        ${tracula_config}
    sed -i '/cvstemp/s:^:#:' ${tracula_config}
    sed -i '/cvstempdir/s:^:#:' ${tracula_config}
    trac-all -c ${tracula_config} -intra -masks
fi
#-------------------------------------------------------------------------------

echo -e "\n==========================================================="
echo -e "Pulling out seed ROI's into individual files"
echo -e "==========================================================="
labelfile=/parietal/dnl_library/bin/fsl/${atlas}.txt
cd ${seed_dir}
count=0
total=$(wc -l ${labelfile} | awk '{print $1}')
cat ${labelfile} |
while read line; do
    count=$(( $count + 1 ))
    printf "\r ROI number: $count/$total"
    roiID=$(echo ${line} | awk '{print $1}' -)
    roiNAME=$(echo ${line} | awk '{print $2}' -)
    fslmaths ${atlas_image} -thr ${roiID} -uthr ${roiID} \
        -bin ${roiNAME}
done

echo -e "\n==========================================================="
echo -e "Transforming ROI's to DWI space"
echo -e "==========================================================="
count=0
for ROI in *.nii.gz; do
    count=$(( $count + 1 ))
    printf "\r ROI number: $count/$total"
    ROIbase=$(basename ${ROI} .nii.gz)
    flirt -in ${ROI} -ref ${aparc_dir}/struct2dwi \
        -out ${ROIbase}2dwi \
        -init ${SUBJECTS_DIR}/${subj}/dmri/xfms/anatorig2diff.bbr.mat -applyxfm
    fslmaths ${ROIbase}2dwi -thr 0.25 -bin ${ROIbase}2dwi_bin
    fslstats ${ROIbase}2dwi_bin -V | awk '{print $1}' >> sizes.txt
done

echo ${PWD}/*_bin.nii.gz | tr " " "\n" >> seeds.txt
cd ${base_dir}
