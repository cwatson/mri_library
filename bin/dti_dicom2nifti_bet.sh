#! /bin/bash
# Chris Watson, 2017-02-28
set -a

usage() {
    cat << !

 Preprocess DTI data using FSL's tools, including the new "eddy" tool.
 This should be run from the base project directory. The
 script expects to find "sourcedata/" (DICOM's) directories, which should be
 BIDS compliant.

 USAGE:
    $(basename $0) [-s SUBJECT] [-t THRESH] [--rerun]
        [--long SESSION] [--acq LABEL]

 OPTIONS:
     -h, --help
         Show this message

     -s, --subject [SUBJECT]
         Subject ID. This will be the "label" in the directories and filenames,
         as outlined by the BIDS spec.

     -t, --threshold [THRESH]
         Intensity threshold for "bet" (default: 0.5)

     --rerun
         Include if you want to re-run "bet"; will skip DICOM extraction and
         conversion to NIfTI

     --long [SESSION]
         If it's a longitudinal study, specify the session label

     --acq [ACQ LABEL]
         If multiple acquisitions, provide the label. For example, the TBI study
         acquired 2 DTI scans; the acq label for the TBI study would be "iso":
            sub-<subLabel>_ses-<sessLabel>_acq-iso_dwi.nii.gz


 EXAMPLES:
     $(basename $0) -s SP7104_time1 -t 0.4
     $(basename $0) -s SP7180_time1 --rerun
     $(basename $0) -s SP7180 --long 01 --acq iso

!
}

# Argument checking
#-------------------------------------------------------------------------------
[[ $# == 0 ]] && usage && exit

TEMP=$(getopt -o hs:t: --long help,subject:,threshold:,rerun,long:,acq: -- "$@")
[[ $? -ne 0 ]] && usage && exit 1
eval set -- "${TEMP}"

thresh=0.5
rerun=0
long=0
sess=''
acq=''
while true; do
    case "$1" in
        -h|--help)      usage && exit ;;
        -s|--subject)   subj="$2"; shift ;;
        -t|--threshold) thresh="$2"; shift ;;
        --rerun)        rerun=1 ;;
        --long)         long=1; sess="$2"; shift ;;
        --acq)          acq="$2"; shift ;;
        *)              break ;;
    esac
    shift
done

source $(dirname $0)/dti_vars.sh

#-------------------------------------------------------------------------------
# Extract and convert DICOMs, if necessary
#-------------------------------------------------------------------------------
if [[ ${rerun} -eq 0 ]]; then
    mkdir -p ${rawdir} ${resdir}
    cd ${projdir}/${srcdir}

    # Extract first file, determine Manufacturer,
    # then extract entire archive
    #-------------------------------------------------------
    firstfile=$(tar tf ${target}_dicom.tar.gz | grep -v '/$' | head -1)
    tar xf ${target}_dicom.tar.gz ${firstfile} --xform='s#^.+/##x'
    manuf=$(dcmdump +P 0008,0070 $(basename ${firstfile}) | cut -d"[" -f2 | cut -d"]" -f1)
    rm $(basename ${firstfile})

    mkdir tmp
    if [[ ${manuf} == *"Philips"* ]]; then
        # Philips data I've processed has a "0000001" directory; don't remove
        tar xf ${target}_dicom.tar.gz -C tmp
    else
        tar xf ${target}_dicom.tar.gz --xform='s#^.+/##x' -C tmp
    fi

    # Convert DICOMs to NIfTI
    #-------------------------------------------------------
    dcmconv=$(type -P dcm2niix)
    ${dcmconv} -z i -b y -f ${target} -o . tmp
    rm -r tmp

    # Copy files to results directory; average the b0's
    #-------------------------------------------------------
    lowb=$(awk '{for(i=1;i<=NF;i++){if($i==0)x[i]=i}}END{for(i in x){print x[i] - 1}}' ${target}.bval)
    mv ${target}.{bvec,bval,json,nii.gz} ${projdir}/${rawdir}/
    cd ${projdir}/${resdir}
    ln ${projdir}/${rawdir}/${target}.bval bvals
    ln ${projdir}/${rawdir}/${target}.bvec bvecs.norot
    ln ${projdir}/${rawdir}/${target}.nii.gz dwi_orig.nii.gz

    ct=1
    for i in ${lowb}; do
        fslroi dwi_orig lowb${ct} ${i} 1
        let "ct += 1"
    done
    fslmerge -t lowb lowb[[:digit:]]*
    rm lowb[[:digit:]]*
    fslmaths lowb -Tmean nodif

else
    cd ${projdir}/${resdir}
fi

${FSLDIR}/bin/bet nodif{,_brain} -m -R -f ${thresh}
