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
                ATLAS=$2
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

if [[ -z ${group} ]]
then
    echo "Must provide a group name!"
    exit 3
fi
if [[ -z ${subj} ]]
then
    echo "Must provide a subject ID!"
    exit 4
fi
if [[ -z ${proj} ]]
then
    echo "Must provide a project name!"
    exit 5
fi

# Set directory variables
#-------------------------------------------------------------------------------
if [[ ${proj} == 'CCFA' ]]
then
    scanner=''
    BASE_DIR='/raid2/fmri8/ibd/ccfa'
else
    if [[ -z ${scanner} ]]
    then
        echo "Must provide a scanner (1.5T or 3T)!"
        exit 3
    fi
    BASE_DIR='/raid2/fmri8/fontan'
fi
DTI_DIR=${BASE_DIR}/dti/${scanner}/${group}/${subj}
SUBJECTS_DIR=${BASE_DIR}/volumetric/freesurfer/${scanner}/${group}
SEED_DIR=${BASE_DIR}/dti/${scanner}/${group}/${subj}.probtrackX2/seeds/${ATLAS}
APARC_DIR=${DTI_DIR}/struct/
MRI_DIR=${SUBJECTS_DIR}/${subj}/mri

mkdir -p ${APARC_DIR} ${SEED_DIR}

if [[ ${ATLAS} == 'dkt.scgm' ]]
then
    ATLAS_BASE="aparc.DKTatlas40+aseg"
    ATLAS_IMAGE="${APARC_DIR}/${ATLAS_BASE}.nii.gz"
    if [ ! -e "${ATLAS_IMAGE}" ]
    then
        if [ ! -e "${MRI_DIR}/${ATLAS_BASE}.mgz" ]
        then
            mri_aparc2aseg --s ${subj} --annot aparc.DKTatlas40
        fi
        mri_convert ${MRI_DIR}/${ATLAS_BASE}.{mgz,nii.gz}
        mv ${MRI_DIR}/${ATLAS_BASE}.nii.gz ${APARC_DIR}
    fi
elif [[ ${ATLAS} == 'destrieux.scgm' ]]
then
    ATLAS_IMAGE="${APARC_DIR}/aparc.a2009s+aseg.nii.gz"
    if [ ! -e "${ATLAS_IMAGE}" ]
    then
        mri_convert ${MRI_DIR}/aparc.a2009s+aseg.{mgz,nii.gz}
        mv ${MRI_DIR}/aparc.a2009s+aseg.nii.gz ${APARC_DIR}
    fi
else
    echo "Invalid atlas! Choose 'dkt.scgm' or 'destrieux.scgm'"
    exit 4
fi

cd ${APARC_DIR}
if [ ! -e "${APARC_DIR}/norm.nii.gz" ]
then
    mri_convert ${MRI_DIR}/norm.mgz ${APARC_DIR}/norm.nii.gz
    bet2 norm struct_brain -m -f 0.35
fi
if [ ! -e "${APARC_DIR}/struct2dwi.nii.gz" ]
then
    echo -e "\n==========================================================="
    echo -e "Registering 'norm' to DWI space"
    echo -e "==========================================================="
    flirt -in struct_brain -ref ../dwi -out struct2dwi
fi

#-------------------------------------------------------------------------------
# Check if the transforms from Tracula exist; if not, create them
#-------------------------------------------------------------------------------
if [ ! -e "${SUBJECTS_DIR}/${subj}/dmri/xfms/anatorig2diff.bbr.mat" ]
then
    mkdir -p ${SUBJECTS_DIR}/${subj}/{dmri,dlabel/diff}
    FS_DTI_DIR=${SUBJECTS_DIR}/${subj}/dmri
    ln -s ${DTI_DIR}/{dwi_orig.nii.gz,dwi.nii.gz,dwi.ecclog} ${FS_DTI_DIR}/
    ln -s ${FS_DTI_DIR}/dwi_orig.nii.gz ${FS_DTI_DIR}/dwi_orig_flip.nii.gz
    ln -s ${FS_DTI_DIR}/dwi.nii.gz ${FS_DTI_DIR}/data.nii.gz
    ln -s ${SUBJECTS_DIR}/bvecs_transpose ${FS_DTI_DIR}/dwi_orig.mghdti.bvecs
    ln -s ${SUBJECTS_DIR}/bvals_transpose ${FS_DTI_DIR}/dwi_orig.mghdti.bvals
    ln -s ${DTI_DIR}/{bvals,bvecs,lowb.nii.gz,lowb_brain.nii.gz} ${FS_DTI_DIR}/
    ln -s ${DTI_DIR}/lowb_brain_mask.nii.gz ${SUBJECTS_DIR}/${subj}/dlabel/diff

    for meas in FA MD L1 L2 L3
    do
        ln -s ${DTI_DIR}/dtifit/${subj}_dtifit_${meas}.nii.gz \
            ${FS_DTI_DIR}/dtifit_${meas}.nii.gz
    done

    # Run the remaining steps of trac-all -prep
    TRACULA_CONFIG=${SUBJECTS_DIR}/dmrirc/dmrirc.${subj}
    cp ${FREESURFER_HOME}/bin/dmrirc.example ${TRACULA_CONFIG}
    sed -i "s:/path/to/recons/of/ducks:${SUBJECTS_DIR}:" ${TRACULA_CONFIG}
    sed -i "s:/path/to/tracts/of/ducks:${SUBJECTS_DIR}:" ${TRACULA_CONFIG}
    sed -i "s/(huey dewey louie)/${subj}/" ${TRACULA_CONFIG}
    sed -i 's/(1 3)/1/' ${TRACULA_CONFIG}
    sed -i "s:/path/to/dicoms/of/ducks:${DTI_DIR}/archives:" ${TRACULA_CONFIG}
    sed -i 's:(huey/day1.*::' ${TRACULA_CONFIG}
    sed -i '64,66d' ${TRACULA_CONFIG}
    sed -i "s:/path/to/bvecs.txt:${SUBJECTS_DIR}/bvecs_transpose:" ${TRACULA_CONFIG}
    sed -i "s:/path/to/bvals.txt:${SUBJECTS_DIR}/bvals_transpose:" ${TRACULA_CONFIG}
    sed -i '/dob0/s:1:0:' ${TRACULA_CONFIG}
    sed -i '/dcmroot/s:^:#:' ${TRACULA_CONFIG}
    sed -i '/b0mlist/s:^:#:' ${TRACULA_CONFIG}
    sed -i '/b0plist/s:^:#:' ${TRACULA_CONFIG}
    sed -i '/echospacing/s:^:#:' ${TRACULA_CONFIG}
    sed -i '/thrbet/s:^:#:' ${TRACULA_CONFIG}
    sed -i 's:/path/to/mni_template:/parietal/fsl/current/data/standard/MNI152_T1_1mm_brain:' \
        ${TRACULA_CONFIG}
    sed -i '/cvstemp/s:^:#:' ${TRACULA_CONFIG}
    sed -i '/cvstempdir/s:^:#:' ${TRACULA_CONFIG}
    trac-all -c ${SUBJECTS_DIR}/dmrirc/dmrirc.${subj} \
        -prep -nocorr -noqa -notensor -noprior
fi
#-------------------------------------------------------------------------------

echo -e "\n==========================================================="
echo -e "Pulling out seed ROI's into individual files"
echo -e "==========================================================="
labelfile=/parietal/dnl_library/bin/fsl/${ATLAS}.txt
count=0
total=$(wc -l ${labelfile} | awk '{print $1}')
mkdir tmp
cat ${labelfile} |
while read line
do
    count=$(( $count + 1 ))
    printf "\r ROI number: $count/$total"
    roiID=$(echo ${line} | awk '{print $1}' -)
    roiNAME=$(echo ${line} | awk '{print $2}' -)
    fslmaths ${ATLAS_IMAGE} -thr ${roiID} -uthr ${roiID} \
        -bin tmp/${roiNAME}
done
mv tmp/* ${SEED_DIR}
rmdir tmp
cd ${SEED_DIR}

echo -e "\n==========================================================="
echo -e "Transforming ROI's to DWI space"
echo -e "==========================================================="
count=0
for ROI in *.nii.gz
do
    count=$(( $count + 1 ))
    printf "\r ROI number: $count/$total"
    ROIbase=$(basename ${ROI} .nii.gz)
    flirt -in ${ROI} -ref ${APARC_DIR}/struct2dwi \
        -out ${ROIbase}2dwi \
        -init ${SUBJECTS_DIR}/${subj}/dmri/xfms/anatorig2diff.bbr.mat -applyxfm
    fslmaths ${ROIbase}2dwi -thr 0.25 -bin ${ROIbase}2dwi_bin
    fslstats ${ROIbase}2dwi_bin -V | awk '{print $1}' >> sizes.txt
done

ls ${PWD}/*_bin.nii.gz >> seeds.txt
cd ${BASE_DIR}
