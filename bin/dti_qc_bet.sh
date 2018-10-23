#! /bin/bash
# Chris Watson, 2018-08-08
set -a

usage() {
    cat << !

 Perform QC on the skull-stripping step from "dti_dicom2nifti_bet.sh". Utilizes
 "overlay" and "slicer" programs from FSL, along with programs from
 "ImageMagick".

 USAGE: $(basename $0) [OPTIONS]

 OPTIONS:
     -h, --help
         Show this message

     -s, --subject [SUBJECT]
         Subject ID. This will be the "label" as outlined by the BIDS spec

     --long [SESSION]
         If it's a longitudinal study, specify the session label

     --acq [ACQ LABEL]
         If multiple acquisitions, provide the label. For example, the TBI study
         acquired 2 DTI scans; the acq label for the TBI studywould be "iso":
            sub-<subLabel>_ses-<sessLabel>_acq-iso_dwi.nii.gz


 EXAMPLE:
     $(basename $0) -s SP7180 --long 01 --acq iso

!
}

# Argument checking
#-------------------------------------------------------------------------------
[[ $# == 0 ]] && usage && exit

TEMP=$(getopt -o hs: --long help,subject:,long:,acq: -- "$@")
[[ $? -ne 0 ]] && usage && exit 1
eval set -- "${TEMP}"

long=0
sess=''
acq=''
while true; do
    case "$1" in
        -h|--help)      usage && exit ;;
        -s|--subject)   subj="$2"; shift ;;
        --long)         long=1; sess="$2"; shift ;;
        --acq)          acq="$2"; shift ;;
        * )             break ;;
    esac
    shift
done

source $(dirname $0)/dti_vars.sh

# bet QC
#-------------------------------------------------------------------------------
cd ${projdir}/${resdir}
[[ ! -d qc_bet ]] && mkdir qc_bet
lower=$(${FSLDIR}/bin/fslstats nodif_brain -P 1)
upper=$(${FSLDIR}/bin/fslstats nodif_brain -P 90)
${FSLDIR}/bin/overlay 1 0 nodif -a nodif_brain ${lower} ${upper} qc_bet/qc_bet
cd qc_bet
${FSLDIR}/bin/slicer qc_bet -s 2 -S 2 1200 qc_bet_ax.png

# Get screenshots for the middle 2/3
#---------------------------------------
dim2=$(${FSLDIR}/bin/fslval qc_bet dim2)
third=$(( ${dim2} / 3 ))
nsag=$(( ${dim2} - ${third} ))
for (( slice=${third}; slice <= ${nsag}; slice+=2 )); do
    fname=slice_$(printf %0.3i ${slice}).png
    ${FSLDIR}/bin/slicer qc_bet -s 2 -x -${slice} ${fname}
done
imsize=$(identify -format "%wx%h" ${fname})
montage -geometry ${imsize} \
    slice_*.png \
    qc_bet_sag.png
rm slice_*.png
