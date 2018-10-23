#! /bin/bash
# Chris Watson, 2018-08-08
set -a

usage() {
    cat << !

 Perform QC on `eddy` results using the new `eddyqc` tool.

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

# eddy QC
#-------------------------------------------------------------------------------
cd ${projdir}/${resdir}
[[ -d eddy/dwi_eddy.qc ]] && rm -r eddy/dwi_eddy.qc
eddy_quad eddy/dwi_eddy -idx eddy/index.txt -par eddy/acqparams.txt -m nodif_brain_mask -b bvals

# tSNR
#-------------------------------------------------------------------------------
#${FSLDIR}/bin/fslmaths data -Tmean mean
#${FSLDIR}/bin/fslmaths data -Tstd std
#${FSLDIR}/bin/fslmaths mean -div std tsnr
#${FSLDIR}/bin/fslmaths tsnr -mas nodif_brain_mask tsnr_mask
#echo $(${FSLDIR}/bin/fslstats tsnr_mask -l 0 -M) >> tsnr.txt
