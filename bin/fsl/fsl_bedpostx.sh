#! /bin/bash
# Chris Watson, 2018-08-12
set -a

usage() {
    cat << !

 Run "bedpostx" for a single subject. The commands to run (for each slice)
 are placed in the "commands.txt" file in the subject directory. This script is
 meant for systems that do not have a CUDA-enabled GPU. In addition to the
 options below, the script accepts the options for "xfibres"; see that
 function's documentation for details.

 USAGE: $(basename $0) [OPTIONS]

 OPTIONS:
    -h, --help
        Show this message

    -s, --subject [SUBJECT]
        Subject ID. If you don't specify "--bids", then [SUBJECT] should be the
        directory name. If you do, it should be the subject label.

    --bids
        Include if your study is BIDS compliant

    --long [SESSION]
        If it's a longitudinal study, specify the session label. Only valid if
        BIDS compliant

    --acq [ACQ LABEL]
        If multiple acquisitions, provide the label. For example, the TBI study
        acquired 2 DTI scans; the acq label for the TBI study would be "iso":
            sub-<subLabel>_ses-<sessLabel>_acq-iso_dwi.nii.gz

 EXAMPLE:
    $(basename $0) -s SP7180 --bids --long 01 --acq iso

!
}

# Argument checking
#-------------------------------------------------------------------------------
[[ $# == 0 ]] && usage && exit

TEMP=$(getopt -o hs:n:w:b:j: --long help,subject:,bids,long:,acq:,model:,se: -- "$@")
[[ $? -ne 0 ]] && usage && exit 1
eval set -- "${TEMP}"

bids=0
long=0
sess=''
acq=''

# xfibres option defaults
nfibres=3
fudge=1
burnin=1000
njumps=1250
sampleevery=25
model=2
while true; do
    case "$1" in
        -h|--help)      usage && exit ;;
        -s|--subject)   subj="$2"; shift ;;
        --bids)         bids=1 ;;
        --long)         long=1; sess="$2"; shift ;;
        --acq)          acq="$2"; shift ;;
        -n)             nfibres=$2; shift ;;
        -w)             fudge=$2; shift ;;
        -b)             burnin=$2; shift ;;
        -j)             njumps=$2; shift ;;
        --se)           sampleevery=$2; shift ;;
        --model)        model=$2; shift ;;
        * )             break ;;
    esac
    shift
done
opts="--nf=$nfibres --fudge=$fudge --bi=$burnin --nj=$njumps --se=$sampleevery --model=$model --cnonlinear"

source $(dirname $0)/fsl_dti_vars.sh
subjdir=$(realpath ${resdir/\/$/})
bpxdir=${subjdir}.bedpostX

# Preprocessing
#-------------------------------------------------------------------------------
echo Results directory is ${subjdir}
echo Making bedpostx directory structure
mkdir -p ${bpxdir}/{diff_slices,logs/monitor,xfms}
export LAUNCHER_JOB_FILE=${bpxdir}/commands.txt

echo Queuing preprocessing stages
export LC_ALL=C
cp ${subjdir}/{bvecs,bvals,nodif_brain.nii.gz,nodif_brain_mask.nii.gz} ${bpxdir}
${FSLDIR}/bin/fslslice ${subjdir}/data
${FSLDIR}/bin/fslslice ${subjdir}/nodif_brain_mask

# Parallel processing stage
#-------------------------------------------------------------------------------
echo Queuing parallel processing stage
nslices=$(${FSLDIR}/bin/fslval ${subjdir}/data dim3)
slice=0
while [ $slice -lt $nslices ]; do
    echo "${FSLDIR}/bin/bedpostx_single_slice.sh ${subjdir} ${slice} $opts" >> ${LAUNCHER_JOB_FILE}
    slice=$(($slice + 1))
done
