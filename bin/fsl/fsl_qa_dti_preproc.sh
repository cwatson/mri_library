#! /bin/bash
# Chris Watson, 2018-08-08
set -a

usage() {
    cat << !

 Perform QA on the skull-stripping step from `fsl_dti_preproc.sh`. Utilizes
 "overlay" and "slicer" programs from FSL.

 USAGE: $(basename $0) [OPTIONS]

 OPTIONS:
     -h, --help
         Show this message

     -s, --subject [SUBJECT]
         Subject ID. If you don't specify "--bids", then [SUBJECT] should be
         the directory name. If you do, it should be the subject label.

     --bids
         Include if your study is BIDS compliant

     --long [SESSION]
         If it's a longitudinal study, specify the session label. Only valid if
         BIDS compliant

     --acq [ACQ LABEL]
         If multiple acquisitions, provide the label. For example, the TBI study
         acquired 2 DTI scans; the acq label for "dti2" would be "iso", e.g.
            sub-<subLabel>_ses-<sessLabel>_acq-iso_dwi.nii.gz


 EXAMPLE:
     $(basename $0) -s SP7180 --bids --long 01 --acq iso

!
}

# Argument checking
#-------------------------------------------------------------------------------
[[ $# == 0 ]] && usage && exit

TEMP=$(getopt -o hs: --long help,subject,bids,long:,acq: -- "$@")
[[ $? -ne 0 ]] && usage && exit 1
eval set -- "${TEMP}"

bids=0
long=0
sess=''
acq=''
while true; do
    case "$1" in
        -h|--help)          usage && exit ;;
        -s|--subject)       subj="$2"; shift ;;
        --bids)             bids=1 ;;
        --long)             long=1; sess="$2"; shift ;;
        --acq)              acq="$2"; shift ;;
        * )                 break ;;
    esac
    shift
done

source $(dirname $0)/fsl_dti_vars.sh

# bet QA
#-------------------------------------------------------------------------------
cd ${projdir}/${resdir}
[[ ! -d qa_bet ]] && mkdir qa_bet
lower=$(${FSLDIR}/bin/fslstats nodif_brain -P 1)
upper=$(${FSLDIR}/bin/fslstats nodif_brain -P 90)
overlay 1 0 nodif -a nodif_brain ${lower} ${upper} qa_bet/qa_bet
cd qa_bet
slicer qa_bet -s 2 -S 2 1200 qa_bet_ax.png

dim2=$(fslval qa_bet dim2)
nsag=$(( ${dim2} - 20 ))
for (( slice=19; slice <= ${nsag}; slice+=2 )); do
    fname=slice_$(printf %0.3i ${slice}).png
    slicer qa_bet -s 2 -x -${slice} ${fname}
done
imsize=$(identify -format "%wx%h" ${fname})
montage -geometry ${imsize} \
    slice_*.png \
    qa_bet_sag.png
rm slice_*.png

# Eddy QA
#-------------------------------------------------------------------------------
cd ${projdir}/${resdir}
eddy_quad eddy/dwi_eddy -idx index.txt -par acqparams.txt -m nodif_brain_mask -b bvals

# tSNR
#-------------------------------------------------------------------------------
#fslmaths data -Tmean mean
#fslmaths data -Tstd std
#fslmaths mean -div std tsnr
#fslmaths tsnr -mas nodif_brain_mask tsnr_mask
#echo $(fslstats tsnr_mask -l 0 -M) >> tsnr.txt
