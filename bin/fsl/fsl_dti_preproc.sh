#! /bin/bash
#
# Script to run DTI preprocessing with the new "eddy" tool.
#_______________________________________________________________________________
# by Chris Watson, 2017-02-28

usage() {
    cat << !

 Preprocess DTI data using FSL's tools, including the new "eddy" tool. If you
 specify "--bids", this should be run from the base project directory. The
 script expects to find "sourcedata/" (DICOM's) and "rawdata" directories; both
 of which should be BIDS compliant.

 USAGE: $(basename $0) [options]

 OPTIONS:
     -h, --help
         Show this message

     -s, --subject [SUBJECT]
         Subject ID. If you don't specify "--bids", then [SUBJECT] should be
         the directory name. If you do, it should be the subject label.

     -t, --threshold [THRESH]
         Intensity threshold for "bet" (default: 0.5)

     --rerun
         Include if you are re-running; will re-do "bet" and "eddy"

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
     $(basename $0) -s SP7104_time1 -t 0.4
     $(basename $0) -s SP7180_time1 --rerun
     $(basename $0) -s SP7180 --bids --long 01 --acq iso

!
}

# Argument checking
#-------------------------------------------------------------------------------
[[ $# == 0 ]] && usage && exit

TEMP=$(getopt -o hs:t: --long help,subject,threshold,rerun,bids,long:,acq: -- "$@")
[[ $? -ne 0 ]] && usage && exit 1
eval set -- "${TEMP}"

thresh=0.5
rerun=0
bids=0
long=0
sess=''
acq=''
while true; do
    case "$1" in
        -h|--help)          usage && exit ;;
        -s|--subject)       subj="$2"; shift ;;
        -t|--threshold)     thresh="$2"; shift ;;
        --rerun)            rerun=1; shift ;;
        --bids)             bids=1; shift ;;
        --long)             long=1; sess="$2"; shift ;;
        --acq)              acq="$2"; shift ;;
        * )                 break ;;
    esac
    shift
done

[[ ! -d ${subj} ]] && echo -e "Subject ${subj} is not valid!\n" && exit 2

projdir=${PWD}
if [[ ${bids} -eq 1 ]]; then
    target=sub-${subj}
    rawdir=rawdata/sub-${subj}/
    if [[ ${long} -eq 1 ]]; then
        target=${target}_ses-${sess}
        rawdir=${rawdir}/ses-${sess}
    fi
    if [[ ${acq} != '' ]]; then
        target=${target}_acq-${acq}_dwi
    fi
    rawdir=${rawdir}/dwi
    srcdir=${rawdir/rawdata/sourcedata}
    resdir=${rawdir/rawdata/tractography}
    resdir=${resdir/dwi/dti2}
else
    target=dwi_orig
    rawdir=${subj}
    if [[ ${acq} != '' ]]; then
        rawdir=${rawdir}/${acq}
    fi
    srcdir=${rawdir}
    resdir=${rawdir}
fi

#-------------------------------------------------------------------------------
# Extract and convert DICOMs, if necessary
#-------------------------------------------------------------------------------
if [[ ${rerun} -eq 0 ]]; then
    cd ${projdir}/${srcdir}
    tar zxf dicom.tar.gz
    dcmconv=$(which dcm2niix)
    ${dcmconv} -z i -b y -f ${target} -o . DICOM/
    rm -r DICOM

    cp ${target}.bvec ${projdir}/${resdir}/bvecs.norot
    cp ${target}.bval ${projdir}/${resdir}/bvals
    if [[ ${bids} -eq 1 ]]; then
        mv ${target}.{bvec,bval,json,nii.gz} ${projdir}/${rawdir}/
        cd ${projdir}/${rawdir}
        ln -sr ${target}.nii.gz ${projdir}/${resdir}/dwi_orig.nii.gz
        cd ${projdir}/${resdir}
    fi
    fslroi dwi_orig nodif 0 1

    printf "0 1 0 0.0646" > acqparams.txt
    nvols=$(fslnvols dwi_orig)
    indx=""
    for ((i=1; i<=${nvols}; i+=1)); do indx="$indx 1"; done
    echo $indx > index.txt
    mkdir -p eddy
else
    cd ${projdir}/${resdir}
fi

bet nodif{,_brain} -m -R -f ${thresh}

#-------------------------------------------------------------------------------
# Run eddy
#-------------------------------------------------------------------------------
echo -e '\n Running "eddy"!'
#eddy_openmp \
#    --imain=dwi_orig \
#    --mask=nodif_brain_mask \
#    --index=index.txt \
#    --acqp=acqparams.txt \
#    --bvecs=bvecs.norot \
#    --bvals=bvals \
#    --repol \
#    --out=eddy/dwi_eddy
#ln -sr eddy/dwi_eddy.nii.gz data.nii.gz
#ln -sr eddy/dwi_eddy.eddy_rotated_bvecs bvecs
#
##-------------------------------------------------------------------------------
## Run dtifit
##-------------------------------------------------------------------------------
#mkdir -p dtifit
#dtifit -k data -m nodif_brain_mask -o dtifit/dtifit \
#    -r bvecs -b bvals --sse --save_tensor
#fslmaths dtifit/dtifit_L2 \
#    -add dtifit/dtifit_L3 \
#    -div 2 \
#    dtifit/dtifit_RD
