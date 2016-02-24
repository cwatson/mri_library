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
        --basedir   The project's base directory
        -g          Subject group
        -s          Subject name/ID
        -p          Project name (e.g. Fontan)
        --scanner   Scanner (either 1.5T or 3T)

    EXAMPLES:
        $(basename $0) --basedir /raid2/fmri8/ibd/ccfa/ -g case -s cd001 -p CCFA
        $(basename $0)
            --basedir /raid2/fmri8/fontan
            -g control
            -s 02-430-4
            -p Fontan
            --scanner 1.5T

!
}

# Check arguments
#-------------------------------------------------------------------------------
while :
do
    case $1 in
        -h)
            usage
            exit 1
            ;;

        --basedir)
            if [ -n "$2" ]
            then
                basedir=$2
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


if [[ ${proj} == 'CCFA' ]]
then
    # Convert the norm volume to NIfTI
    #-------------------------------------------------------
    mri_convert ${basedir}/volumetric/freesurfer/${group}/${subj}/mri/norm.{mgz,nii.gz}
    mkdir -p ${basedir}/dti/${group}/${subj}/struct
    mv ${basedir}/volumetric/freesurfer/${group}/${subj}/mri/norm.nii.gz \
        ${basedir}/dti/${group}/${subj}/struct
    cd ${basedir}/dti/${group}/${subj}/struct
    bet2 norm.nii.gz struct_brain -m

    # Transform images to DWI spaces
    #-------------------------------------------------------
    echo -e "\n==========================================================="
    echo -e "Transforming to DWI space"
    echo -e "==========================================================="
    flirt -in struct_brain -ref ../dwi -out struct2dwi
    flirt -in struct2dwi \
        -ref ${FSLDIR}/data/standard/MNI152_T1_2mm_brain \
        -omat dwi2standard.mat
    convert_xfm -omat standard2dwi.mat -inverse dwi2standard.mat
    flirt -in /parietal/matlab/spm8/toolbox/AAL/ROI_MNI_V4.nii \
        -ref struct2dwi -out AAL2dwi -init standard2dwi.mat -applyxfm

    # Separate out the seed ROI's
    #-------------------------------------------------------
    echo -e "\n==========================================================="
    echo -e "Pulling out seed ROI's into individual files"
    echo -e "==========================================================="
    cd ${basedir}
    mkdir -p ${subj}.probtrackX2/seeds
    cd ${subj}.probtrackX2/seeds
    head -90 /parietal/matlab/spm8/toolbox/AAL/ROI_MNI_V4.txt |
    while read line
    do
        thresh=$(echo ${line} | awk '{print $3}' -)
        name=$(echo ${line} | awk '{print $2}' -)
        fslmaths ../../${subj}/struct/AAL2dwi -thr ${thresh} -uthr ${thresh} ${thresh}_${name}
    done

#===============================================================================
# Code for DKT+SCGM atlas
#===============================================================================
else
    APARC_DIR=${basedir}/dti/${scanner}/${group}/${subj}/struct/aparc
    SUBJECTS_DIR=${basedir}/volumetric/freesurfer/${scanner}/${group}
    MRI_DIR=${SUBJECTS_DIR}/${subj}/mri
    SEED_DIR=${basedir}/dti/${scanner}/${group}/${subj}.probtrackX2/seeds
    mkdir -p ${APARC_DIR}
    mkdir -p ${SEED_DIR}

    if [ ! -e "${MRI_DIR}/aparc.DKTatlas40+aseg.mgz" ]
    then
        mri_aparc2aseg --s ${subj} --annot aparc.DKTatlas40
        mri_convert ${MRI_DIR}/aparc.DKTatlas40+aseg.{mgz,nii.gz}
    fi
    cp ${MRI_DIR}/aparc.DKTatlas40+aseg.nii.gz ${APARC_DIR}
    cd ${APARC_DIR}
    bet2 ../norm struct_brain -m -f 0.35
    flirt -in struct_brain -ref ../../dwi -out struct2dwi

    fslmaths aparc.DKTatlas40+aseg.nii.gz -thr 1002 -uthr 1002 -bin 1002_lcACC
    fslmaths aparc.DKTatlas40+aseg.nii.gz -thr 1003 -uthr 1003 -bin 1003_lcMFG
    fslmaths aparc.DKTatlas40+aseg.nii.gz -thr 1005 -uthr 1005 -bin 1005_lCUN
    fslmaths aparc.DKTatlas40+aseg.nii.gz -thr 1006 -uthr 1006 -bin 1006_lENT
    fslmaths aparc.DKTatlas40+aseg.nii.gz -thr 1007 -uthr 1007 -bin 1007_lFUS
    fslmaths aparc.DKTatlas40+aseg.nii.gz -thr 1008 -uthr 1008 -bin 1008_lIPL
    fslmaths aparc.DKTatlas40+aseg.nii.gz -thr 1009 -uthr 1009 -bin 1009_lITG
    fslmaths aparc.DKTatlas40+aseg.nii.gz -thr 1010 -uthr 1010 -bin 1010_liCING
    fslmaths aparc.DKTatlas40+aseg.nii.gz -thr 1011 -uthr 1011 -bin 1011_lLOG
    fslmaths aparc.DKTatlas40+aseg.nii.gz -thr 1012 -uthr 1012 -bin 1012_lLOFC
    fslmaths aparc.DKTatlas40+aseg.nii.gz -thr 1013 -uthr 1013 -bin 1013_lLING
    fslmaths aparc.DKTatlas40+aseg.nii.gz -thr 1014 -uthr 1014 -bin 1014_lmOFC
    fslmaths aparc.DKTatlas40+aseg.nii.gz -thr 1015 -uthr 1015 -bin 1015_lMTG
    fslmaths aparc.DKTatlas40+aseg.nii.gz -thr 1016 -uthr 1016 -bin 1016_lparaH
    fslmaths aparc.DKTatlas40+aseg.nii.gz -thr 1017 -uthr 1017 -bin 1017_lparaC
    fslmaths aparc.DKTatlas40+aseg.nii.gz -thr 1018 -uthr 1018 -bin 1018_lpOPER
    fslmaths aparc.DKTatlas40+aseg.nii.gz -thr 1019 -uthr 1019 -bin 1019_lpORB
    fslmaths aparc.DKTatlas40+aseg.nii.gz -thr 1020 -uthr 1020 -bin 1020_lpTRI
    fslmaths aparc.DKTatlas40+aseg.nii.gz -thr 1021 -uthr 1021 -bin 1021_lperiC
    fslmaths aparc.DKTatlas40+aseg.nii.gz -thr 1022 -uthr 1022 -bin 1022_lpostC
    fslmaths aparc.DKTatlas40+aseg.nii.gz -thr 1023 -uthr 1023 -bin 1023_lpCING
    fslmaths aparc.DKTatlas40+aseg.nii.gz -thr 1024 -uthr 1024 -bin 1024_lpreC
    fslmaths aparc.DKTatlas40+aseg.nii.gz -thr 1025 -uthr 1025 -bin 1025_lPCUN
    fslmaths aparc.DKTatlas40+aseg.nii.gz -thr 1026 -uthr 1026 -bin 1026_lrACC
    fslmaths aparc.DKTatlas40+aseg.nii.gz -thr 1027 -uthr 1027 -bin 1027_lrMFG
    fslmaths aparc.DKTatlas40+aseg.nii.gz -thr 1028 -uthr 1028 -bin 1028_lSFG
    fslmaths aparc.DKTatlas40+aseg.nii.gz -thr 1029 -uthr 1029 -bin 1029_lSPL
    fslmaths aparc.DKTatlas40+aseg.nii.gz -thr 1030 -uthr 1030 -bin 1030_lSTG
    fslmaths aparc.DKTatlas40+aseg.nii.gz -thr 1031 -uthr 1031 -bin 1031_lSMAR
    fslmaths aparc.DKTatlas40+aseg.nii.gz -thr 1034 -uthr 1034 -bin 1034_lTT
    fslmaths aparc.DKTatlas40+aseg.nii.gz -thr 1035 -uthr 1035 -bin 1035_lINS
    fslmaths aparc.DKTatlas40+aseg.nii.gz -thr 10 -uthr 10 -bin 1036_lTHAL
    fslmaths aparc.DKTatlas40+aseg.nii.gz -thr 12 -uthr 12 -bin 1037_lPUT
    fslmaths aparc.DKTatlas40+aseg.nii.gz -thr 13 -uthr 13 -bin 1038_lPALL
    fslmaths aparc.DKTatlas40+aseg.nii.gz -thr 11 -uthr 11 -bin 1039_lCAUD
    fslmaths aparc.DKTatlas40+aseg.nii.gz -thr 17 -uthr 17 -bin 1040_lHIPP
    fslmaths aparc.DKTatlas40+aseg.nii.gz -thr 18 -uthr 18 -bin 1041_lAMYG
    fslmaths aparc.DKTatlas40+aseg.nii.gz -thr 26 -uthr 26 -bin 1042_lACCU

    fslmaths aparc.DKTatlas40+aseg.nii.gz -thr 2002 -uthr 2002 -bin 2002_rcACC
    fslmaths aparc.DKTatlas40+aseg.nii.gz -thr 2003 -uthr 2003 -bin 2003_rcMFG
    fslmaths aparc.DKTatlas40+aseg.nii.gz -thr 2005 -uthr 2005 -bin 2005_rCUN
    fslmaths aparc.DKTatlas40+aseg.nii.gz -thr 2006 -uthr 2006 -bin 2006_rENT
    fslmaths aparc.DKTatlas40+aseg.nii.gz -thr 2007 -uthr 2007 -bin 2007_rFUS
    fslmaths aparc.DKTatlas40+aseg.nii.gz -thr 2008 -uthr 2008 -bin 2008_rIPL
    fslmaths aparc.DKTatlas40+aseg.nii.gz -thr 2009 -uthr 2009 -bin 2009_rITG
    fslmaths aparc.DKTatlas40+aseg.nii.gz -thr 2010 -uthr 2010 -bin 2010_riCING
    fslmaths aparc.DKTatlas40+aseg.nii.gz -thr 2011 -uthr 2011 -bin 2011_rLOG
    fslmaths aparc.DKTatlas40+aseg.nii.gz -thr 2012 -uthr 2012 -bin 2012_rLOFC
    fslmaths aparc.DKTatlas40+aseg.nii.gz -thr 2013 -uthr 2013 -bin 2013_rLING
    fslmaths aparc.DKTatlas40+aseg.nii.gz -thr 2014 -uthr 2014 -bin 2014_rmOFC
    fslmaths aparc.DKTatlas40+aseg.nii.gz -thr 2015 -uthr 2015 -bin 2015_rMTG
    fslmaths aparc.DKTatlas40+aseg.nii.gz -thr 2016 -uthr 2016 -bin 2016_rparaH
    fslmaths aparc.DKTatlas40+aseg.nii.gz -thr 2017 -uthr 2017 -bin 2017_rparaC
    fslmaths aparc.DKTatlas40+aseg.nii.gz -thr 2018 -uthr 2018 -bin 2018_rpOPER
    fslmaths aparc.DKTatlas40+aseg.nii.gz -thr 2019 -uthr 2019 -bin 2019_rpORB
    fslmaths aparc.DKTatlas40+aseg.nii.gz -thr 2020 -uthr 2020 -bin 2020_rpTRI
    fslmaths aparc.DKTatlas40+aseg.nii.gz -thr 2021 -uthr 2021 -bin 2021_rperiC
    fslmaths aparc.DKTatlas40+aseg.nii.gz -thr 2022 -uthr 2022 -bin 2022_rpostC
    fslmaths aparc.DKTatlas40+aseg.nii.gz -thr 2023 -uthr 2023 -bin 2023_rpCING
    fslmaths aparc.DKTatlas40+aseg.nii.gz -thr 2024 -uthr 2024 -bin 2024_rpreC
    fslmaths aparc.DKTatlas40+aseg.nii.gz -thr 2025 -uthr 2025 -bin 2025_rPCUN
    fslmaths aparc.DKTatlas40+aseg.nii.gz -thr 2026 -uthr 2026 -bin 2026_rrACC
    fslmaths aparc.DKTatlas40+aseg.nii.gz -thr 2027 -uthr 2027 -bin 2027_rrMFG
    fslmaths aparc.DKTatlas40+aseg.nii.gz -thr 2028 -uthr 2028 -bin 2028_rSFG
    fslmaths aparc.DKTatlas40+aseg.nii.gz -thr 2029 -uthr 2029 -bin 2029_rSPL
    fslmaths aparc.DKTatlas40+aseg.nii.gz -thr 2030 -uthr 2030 -bin 2030_rSTG
    fslmaths aparc.DKTatlas40+aseg.nii.gz -thr 2031 -uthr 2031 -bin 2031_rSMAR
    fslmaths aparc.DKTatlas40+aseg.nii.gz -thr 2034 -uthr 2034 -bin 2034_rTT
    fslmaths aparc.DKTatlas40+aseg.nii.gz -thr 2035 -uthr 2035 -bin 2035_rINS
    fslmaths aparc.DKTatlas40+aseg.nii.gz -thr 49 -uthr 49 -bin 2036_rTHAL
    fslmaths aparc.DKTatlas40+aseg.nii.gz -thr 51 -uthr 51 -bin 2037_rPUT
    fslmaths aparc.DKTatlas40+aseg.nii.gz -thr 52 -uthr 52 -bin 2038_rPALL
    fslmaths aparc.DKTatlas40+aseg.nii.gz -thr 50 -uthr 50 -bin 2039_rCAUD
    fslmaths aparc.DKTatlas40+aseg.nii.gz -thr 53 -uthr 53 -bin 2040_rHIPP
    fslmaths aparc.DKTatlas40+aseg.nii.gz -thr 54 -uthr 54 -bin 2041_rAMYG
    fslmaths aparc.DKTatlas40+aseg.nii.gz -thr 58 -uthr 58 -bin 2042_rACCU
    mv 1*.nii.gz 2*.nii.gz ${SEED_DIR}
    cd ${SEED_DIR}

    for ROI in *.nii.gz
    do
        ROIbase=$(basename ${ROI} .nii.gz)
        flirt -in ${ROI} -ref ${APARC_DIR}/struct2dwi \
            -out ${ROIbase}2dwi \
            -init ${basedir}/volumetric/freesurfer/${scanner}/${group}/${subj}/dmri/xfms/anatorig2diff.bbr.mat -applyxfm
        fslmaths ${ROIbase}2dwi -thr 0.25 -bin ${ROIbase}2dwi_bin
    done
fi

ls ${PWD}/*_bin.nii.gz >> seeds.txt
cd ${basedir}
