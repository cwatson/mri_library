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
         Include if you are re-running; will re-do "bet" and "eddy"

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

source $(dirname $0)/fsl_dti_vars.sh

#-------------------------------------------------------------------------------
# Extract and convert DICOMs, if necessary
#-------------------------------------------------------------------------------
if [[ ${rerun} -eq 0 ]]; then
    mkdir -p ${rawdir} ${resdir}
    cd ${projdir}/${srcdir}

    # Extract first file, determine Manufacturer
    #-------------------------------------------------------
    firstfile=$(tar tf ${target}_dicom.tar.gz | grep -v '/$' | head -1)
    tar xf ${target}_dicom.tar.gz ${firstfile} --xform='s#^.+/##x'
    manuf=$(dcmdump +P 0008,0070 $(basename ${firstfile}) | cut -d"[" -f2 | cut -d"]" -f1)

    mkdir tmp
    if [[ ${manuf} == *"Philips"* ]]; then
        # Philips data I've processed has a "0000001" directory; don't remove
        tar xf ${target}_dicom.tar.gz -C tmp
    else
        tar xf ${target}_dicom.tar.gz --xform='s#^.+/##x' -C tmp
    fi

    # Convert DICOMs to NIfTI
    #-------------------------------------------------------
    dcmconv=$(which dcm2niix)
    ${dcmconv} -z i -b y -f ${target} -o . tmp
    rm -r tmp

    cp ${target}.bvec ${projdir}/${resdir}/bvecs.norot
    lowb=$(awk '{for(i=1;i<=NF;i++){if($i==0)x[i]=i}}END{for(i in x){print x[i] - 1}}' ${target}.bval)
    cp ${target}.bval ${projdir}/${resdir}/bvals

    reptime=$(grep Repetition ${target}.json | cut -d: -f2 | sed 's/,//')
    manuf=$(grep Manufacturer\" ${target}.json)
    mv ${target}.{bvec,bval,json,nii.gz} ${projdir}/${rawdir}/
    cd ${projdir}/${resdir}
    ln -s ${projdir}/${rawdir}/${target}.nii.gz dwi_orig.nii.gz

    ct=1
    for i in ${lowb}; do
        fslroi dwi_orig lowb${ct} ${i} 1
        let "ct += 1"
    done
    fslmerge -t lowb lowb[[:digit:]]*
    rm lowb[[:digit:]]*
    fslmaths lowb -Tmean nodif

    # Setup for "eddy"
    mkdir -p eddy
    printf "0 1 0 0.0646" > acqparams.txt
    nvols=$(fslnvols dwi_orig)
    indx=""
    for ((i=1; i<=${nvols}; i+=1)); do indx="$indx 1"; done
    echo $indx > index.txt

    # For slice-to-volume correction
    nslices=$(fslval dwi_orig dim3)
    mp=$(expr ${nslices} / 4)   # Max. recommended by Jesper

    if [[ ${manuf} == "Philips" ]]; then
        # For the TBI stress study, DWI is acquired sequentially ("single package default")
        timediff=$(echo "${reptime} / ${nslices}" | bc -l)
        for ((i=0; i<${nslices}; i++)); do
            echo "$i * ${timediff}" | bc -l >> slspec.txt
        done
    fi

else
    cd ${projdir}/${resdir}
fi

${FSLDIR}/bin/bet nodif{,_brain} -m -R -f ${thresh}

#-------------------------------------------------------------------------------
# Run eddy
#-------------------------------------------------------------------------------
export SGE_ROOT=''
echo -e '\n Running "eddy"!'
eddy_cuda \ #openmp \
    --imain=dwi_orig \
    --mask=nodif_brain_mask \
    --index=index.txt \
    --acqp=acqparams.txt \
    --bvecs=bvecs.norot \
    --bvals=bvals \
    --repol \
    --mporder=${mp} \
    --slspec=slspec.txt \
    --residuals \
    --cnr_maps \
    --out=eddy/dwi_eddy
ln -s eddy/dwi_eddy.nii.gz data.nii.gz #TODO change to outlier free?
ln -s eddy/dwi_eddy.eddy_rotated_bvecs bvecs

#-------------------------------------------------------------------------------
# Run dtifit
#-------------------------------------------------------------------------------
mkdir -p dtifit
dtifit -k data -m nodif_brain_mask -o dtifit/dtifit \
    -r bvecs -b bvals --sse --save_tensor
fslmaths dtifit/dtifit_L2 \
    -add dtifit/dtifit_L3 \
    -div 2 \
    dtifit/dtifit_RD
