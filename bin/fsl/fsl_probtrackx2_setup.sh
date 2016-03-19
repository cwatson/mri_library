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
    basedir='/raid2/fmri8/ibd/ccfa'
    APARC_DIR=${basedir}/dti/${group}/${subj}/struct/dkt.scgm
    SUBJECTS_DIR=${basedir}/volumetric/freesurfer/${group}
    MRI_DIR=${SUBJECTS_DIR}/${subj}/mri
    SEED_DIR=${basedir}/dti/${group}/${subj}.probtrackX2/seeds
else
    if [[ -z ${scanner} ]]
    then
        echo "Must provide a scanner (1.5T or 3T)!"
        exit 3
    fi
    basedir='/raid2/fmri8/fontan'
    APARC_DIR=${basedir}/dti/${scanner}/${group}/${subj}/struct/aparc
    SUBJECTS_DIR=${basedir}/volumetric/freesurfer/${scanner}/${group}
    MRI_DIR=${SUBJECTS_DIR}/${subj}/mri
    SEED_DIR=${basedir}/dti/${scanner}/${group}/${subj}.probtrackX2/seeds
fi

mkdir -p ${APARC_DIR}
mkdir -p ${SEED_DIR}

if [ ! -e "${APARC_DIR}/aparc.DKTatlas40+aseg.nii.gz" ]
then
    if [ ! -e "${MRI_DIR}/aparc.DKTatlas40+aseg.mgz" ]
    then
        mri_aparc2aseg --s ${subj} --annot aparc.DKTatlas40
        mri_convert ${MRI_DIR}/aparc.DKTatlas40+aseg.{mgz,nii.gz}
        mv ${MRI_DIR}/aparc.DKTatlas40+aseg.nii.gz ${APARC_DIR}
    else
        if [ ! -e "${MRI_DIR}/aparc.DKTatlas40+aseg.nii.gz" ]
        then
            mri_convert ${MRI_DIR}/aparc.DKTatlas40+aseg.{mgz,nii.gz}
            mv ${MRI_DIR}/aparc.DKTatlas40+aseg.nii.gz ${APARC_DIR}
        fi
    fi
fi
cd ${APARC_DIR}
if [ ! -e "${APARC_DIR}/norm.nii.gz" ]
then
    mri_convert ${MRI_DIR}/norm.mgz ${APARC_DIR}/norm.nii.gz
fi
bet2 norm struct_brain -m -f 0.35
flirt -in struct_brain -ref ../../dwi -out struct2dwi

if [ ! -e "${SUBJECTS_DIR}/${subj}/dmri/xfms/anatorig2diff.bbr.mat" ]
then
    echo "Must run 'trac-all -preproc' first!"
    exit 4
else
    echo -e "\n==========================================================="
    echo -e "Pulling out seed ROI's into individual files"
    echo -e "==========================================================="
    count=0
    total=76
    cat /parietal/dnl_library/bin/fsl/dkt_scgm.txt |
    while read line
    do
        count=$(( $count + 1 ))
        printf "\r ROI number: $count/$total"
        roiID=$(echo ${line} | awk '{print $1}' -)
        roiNAME=$(echo ${line} | awk '{print $2}' -)
        fslmaths aparc.DKTatlas40+aseg.nii.gz -thr ${roiID} -uthr ${roiID} \
            -bin ${roiNAME}
    done
    mv 1*.nii.gz 2*.nii.gz ${SEED_DIR}
    cd ${SEED_DIR}

    echo -e "\n==========================================================="
    echo -e "Transforming ROI's to DWI space"
    echo -e "==========================================================="
    count=0
    total=76
    for ROI in *.nii.gz
    do
        count=$(( $count + 1 ))
        printf "\r ROI number: $count/$total"
        ROIbase=$(basename ${ROI} .nii.gz)
        flirt -in ${ROI} -ref ${APARC_DIR}/struct2dwi \
            -out ${ROIbase}2dwi \
            -init ${SUBJECTS_DIR}/${subj}/dmri/xfms/anatorig2diff.bbr.mat -applyxfm
        fslmaths ${ROIbase}2dwi -thr 0.25 -bin ${ROIbase}2dwi_bin
    done
fi
ls ${PWD}/*_bin.nii.gz >> seeds.txt
cd ${basedir}
