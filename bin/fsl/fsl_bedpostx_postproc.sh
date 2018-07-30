#!/bin/bash

# Parse option arguments
#-------------------------------------------------------------------------------
subjdir=$(realpath ${1}/dti2 | sed 's:/$:$:')
bpx_dir=${subjdir}.bedpostX
export LC_ALL=C

# Postprocessing
#-------------------------------------------------------------------------------
numfib=$(${FSLDIR}/bin/imglob ${bpx_dir}/diff_slices/data_slice_0000/f*samples* | wc -w | awk '{print $1}')
if [ $(${FSLDIR}/bin/imtest ${bpx_dir}/diff_slices/data_slice_0000/f0samples) -eq 1 ]; then
    numfib=$(($numfib - 1))
fi
fib=1
while [ $fib -le $numfib ]; do
    ${FSLDIR}/bin/fslmerge -z ${bpx_dir}/merged_th${fib}samples `${FSLDIR}/bin/imglob ${bpx_dir}/diff_slices/data_slice_*/th${fib}samples*`
    ${FSLDIR}/bin/fslmerge -z ${bpx_dir}/merged_ph${fib}samples `${FSLDIR}/bin/imglob ${bpx_dir}/diff_slices/data_slice_*/ph${fib}samples*`
    ${FSLDIR}/bin/fslmerge -z ${bpx_dir}/merged_f${fib}samples `${FSLDIR}/bin/imglob ${bpx_dir}/diff_slices/data_slice_*/f${fib}samples*`
    ${FSLDIR}/bin/fslmaths ${bpx_dir}/merged_th${fib}samples -Tmean ${bpx_dir}/mean_th${fib}samples
    ${FSLDIR}/bin/fslmaths ${bpx_dir}/merged_ph${fib}samples -Tmean ${bpx_dir}/mean_ph${fib}samples
    ${FSLDIR}/bin/fslmaths ${bpx_dir}/merged_f${fib}samples -Tmean ${bpx_dir}/mean_f${fib}samples

    ${FSLDIR}/bin/make_dyadic_vectors ${bpx_dir}/merged_th${fib}samples ${bpx_dir}/merged_ph${fib}samples ${bpx_dir}/nodif_brain_mask ${bpx_dir}/dyads${fib}
    if [ $fib -ge 2 ]; then
        ${FSLDIR}/bin/maskdyads ${bpx_dir}/dyads${fib} ${bpx_dir}/mean_f${fib}samples
        ${FSLDIR}/bin/fslmaths ${bpx_dir}/mean_f${fib}samples -div ${bpx_dir}/mean_f1samples ${bpx_dir}/mean_f${fib}_f1samples
        ${FSLDIR}/bin/fslmaths ${bpx_dir}/dyads${fib}_thr0.05 -mul ${bpx_dir}/mean_f${fib}_f1samples ${bpx_dir}/dyads${fib}_thr0.05_modf${fib}
        ${FSLDIR}/bin/imrm ${bpx_dir}/mean_f${fib}_f1samples
    fi
    fib=$(($fib + 1))
done

if [ $(${FSLDIR}/bin/imtest ${bpx_dir}/mean_f1samples) -eq 1 ]; then
    ${FSLDIR}/bin/fslmaths ${bpx_dir}/mean_f1samples -mul 0 ${bpx_dir}/mean_fsumsamples
    fib=1
    while [ $fib -le $numfib ]
    do
        ${FSLDIR}/bin/fslmaths ${bpx_dir}/mean_fsumsamples -add ${bpx_dir}/mean_f${fib}samples ${bpx_dir}/mean_fsumsamples
        fib=$(($fib + 1))
    done
fi

# Images to loop through are: mean_{d,d_std,R,f0,S0,tau}samples
for im in ${bpx_dir}/diff_slices/data_slice_0000/mean_*samples.nii.gz; do
    base=$(basename ${im} .nii.gz)
    if [ $(${FSLDIR}/bin/imtest ${im}) -eq 1 ]; then
        ${FSLDIR}/bin/fslmerge -z ${bpx_dir}/${base} \
            $(${FSLDIR}/bin/imglob ${bpx_dir}/diff_slices/data_slice_*/${base}*)
    fi
done

echo Removing intermediate files
if [ `${FSLDIR}/bin/imtest ${bpx_dir}/merged_th1samples` -eq 1 ]; then
    if [ `${FSLDIR}/bin/imtest ${bpx_dir}/merged_ph1samples` -eq 1 ]; then
        if [ `${FSLDIR}/bin/imtest ${bpx_dir}/merged_f1samples` -eq 1 ]; then
            rm -rf ${bpx_dir}/diff_slices
            rm -f ${subjdir}/data_slice_*
            rm -f ${subjdir}/nodif_brain_mask_slice_*
        fi
    fi
fi

echo Creating identity xfm
xfmdir=${bpx_dir}/xfms
echo 1 0 0 0 > ${xfmdir}/eye.mat
echo 0 1 0 0 >> ${xfmdir}/eye.mat
echo 0 0 1 0 >> ${xfmdir}/eye.mat
echo 0 0 0 1 >> ${xfmdir}/eye.mat

echo Done
