#!/bin/bash
set -a

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

if [[ -n ${scriptdir} ]]; then
    source ${scriptdir}/fsl_dti_vars.sh
else
    source $(dirname $0)/fsl_dti_vars.sh
fi
subjdir=$(realpath ${resdir/\/$/})
bpx=${subjdir}.bedpostX
export LC_ALL=C
fsl=${FSLDIR}/bin

# Postprocessing
#-------------------------------------------------------------------------------
numfib=$(${fsl}/imglob ${bpx}/diff_slices/data_slice_0000/f*samples* | wc -w | awk '{print $1}')
if [ $(${fsl}/imtest ${bpx}/diff_slices/data_slice_0000/f0samples) -eq 1 ]; then
    numfib=$(($numfib - 1))
fi
fib=1
while [ $fib -le $numfib ]; do
    ${fsl}/fslmerge -z ${bpx}/merged_th${fib}samples $(${fsl}/imglob ${bpx}/diff_slices/data_slice_*/th${fib}samples*)
    ${fsl}/fslmerge -z ${bpx}/merged_ph${fib}samples $(${fsl}/imglob ${bpx}/diff_slices/data_slice_*/ph${fib}samples*)
    ${fsl}/fslmerge -z ${bpx}/merged_f${fib}samples $(${fsl}/imglob ${bpx}/diff_slices/data_slice_*/f${fib}samples*)
    ${fsl}/fslmaths ${bpx}/merged_th${fib}samples -Tmean ${bpx}/mean_th${fib}samples
    ${fsl}/fslmaths ${bpx}/merged_ph${fib}samples -Tmean ${bpx}/mean_ph${fib}samples
    ${fsl}/fslmaths ${bpx}/merged_f${fib}samples -Tmean ${bpx}/mean_f${fib}samples

    ${fsl}/make_dyadic_vectors ${bpx}/merged_th${fib}samples ${bpx}/merged_ph${fib}samples ${bpx}/nodif_brain_mask ${bpx}/dyads${fib}
    if [ $fib -ge 2 ]; then
        ${fsl}/maskdyads ${bpx}/dyads${fib} ${bpx}/mean_f${fib}samples
        ${fsl}/fslmaths ${bpx}/mean_f${fib}samples -div ${bpx}/mean_f1samples ${bpx}/mean_f${fib}_f1samples
        ${fsl}/fslmaths ${bpx}/dyads${fib}_thr0.05 -mul ${bpx}/mean_f${fib}_f1samples ${bpx}/dyads${fib}_thr0.05_modf${fib}
        ${fsl}/imrm ${bpx}/mean_f${fib}_f1samples
    fi
    fib=$(($fib + 1))
done

if [ $(${fsl}/imtest ${bpx}/mean_f1samples) -eq 1 ]; then
    ${fsl}/fslmaths ${bpx}/mean_f1samples -mul 0 ${bpx}/mean_fsumsamples
    fib=1
    while [ $fib -le $numfib ]; do
        ${fsl}/fslmaths ${bpx}/mean_fsumsamples -add ${bpx}/mean_f${fib}samples ${bpx}/mean_fsumsamples
        fib=$(($fib + 1))
    done
fi

# Images to loop through are: mean_{d, d_std, R, f0, S0, tau}samples
for im in ${bpx}/diff_slices/data_slice_0000/mean_*samples.nii.gz; do
    base=$(basename ${im} .nii.gz)
    if [ $(${fsl}/imtest ${im}) -eq 1 ]; then
        ${fsl}/fslmerge -z ${bpx}/${base} \
            $(${fsl}/imglob ${bpx}/diff_slices/data_slice_*/${base}*)
    fi
done

echo Removing intermediate files
if [ $(${fsl}/imtest ${bpx}/merged_th1samples) -eq 1 ]; then
    if [ $(${fsl}/imtest ${bpx}/merged_ph1samples) -eq 1 ]; then
        if [ $(${fsl}/imtest ${bpx}/merged_f1samples) -eq 1 ]; then
            rm -rf ${bpx}/diff_slices
            rm -f ${subjdir}/data_slice_*
            rm -f ${subjdir}/nodif_brain_mask_slice_*
        fi
    fi
fi

echo Creating identity xfm
xfmdir=${bpx}/xfms
echo 1 0 0 0 > ${xfmdir}/eye.mat
echo 0 1 0 0 >> ${xfmdir}/eye.mat
echo 0 0 1 0 >> ${xfmdir}/eye.mat
echo 0 0 0 1 >> ${xfmdir}/eye.mat

echo Done
