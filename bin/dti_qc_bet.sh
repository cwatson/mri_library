#! /bin/bash
# Chris Watson, 2018-08-08
set -a

usage() {
    cat << !

 Perform QC on the skull-stripping step from "dti_dicom2nifti_bet.sh". Utilizes
 "overlay" and "slicer" programs from FSL, along with programs from
 "ImageMagick".

 This is not meant to be called from the command line. It is called from within
 "dti_dicom2nifti_bet.sh".

!
}

# bet QC
#-------------------------------------------------------------------------------
lower=$(${FSLDIR}/bin/fslstats nodif_brain -P 1)
upper=$(${FSLDIR}/bin/fslstats nodif_brain -P 90)
${FSLDIR}/bin/overlay 1 0 nodif -a nodif_brain ${lower} ${upper} qc/bet/qc_bet
cd qc/bet
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
