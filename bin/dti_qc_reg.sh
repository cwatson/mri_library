#! /bin/bash
set -a

usage() {
    cat << !

 Perform QC on the registration step from "dti_reg_FS_to_diff.sh". Utilizes
 programs from the "ImageMagick" suite. It creates, within "${resdir}/qc/reg",
 a composite image of the parcellation overlaid on the FA, a GIF of the same
 images, and a GIF alternating between the FA and the overlay for each slice.

 This is not meant to be called from the command line. It is called from within
 "dti_reg_FS_to_diff.sh".

!
}

qcdir=${projdir}/${resdir}/qc/reg
mkdir -p ${qcdir}

nslices=$(${FSLDIR}/bin/fslval ${resdir}/nodif dim3)
startslice=$(( ${nslices} / 5 ))
endslice=$(( ${nslices} - ${startslice} ))
midline=$(( $(${FSLDIR}/bin/fslval ${resdir}/nodif dim2) / 2 ))

# Create text file with "freeview" commands; loop through slices
#-------------------------------------------------------------------------------
fv_cmd=${qcdir}/cmd.txt
echo "-v ${resdir}/dtifit/dtifit_FA.nii.gz" >> ${fv_cmd}
echo "-zoom 1.25 -viewsize 640 480" >> ${fv_cmd}

# Screenshots of just the FA volume
for (( slice=${startslice}; slice <= ${endslice}; slice +=2 )); do
    fname=${qcdir}/slice_$(printf %0.3i ${slice})_fa.png
    echo "-viewport axial -slice 0 ${midline} ${slice} -ss ${fname}" >> ${fv_cmd}
done
# Screenshots with the overlay
echo "-v ${resdir}/registrations/diff/${atlas_base}.bbr.nii.gz:colormap=lut:lut=FreeSurferColorLUT" >> ${fv_cmd}
for (( slice=${startslice}; slice <= ${endslice}; slice +=2 )); do
    fname=${qcdir}/slice_$(printf %0.3i ${slice})_overlay.png
    echo "-viewport axial -slice 0 ${midline} ${slice} -ss ${fname}" >> ${fv_cmd}
done
echo "-quit" >> ${fv_cmd}
xvfb-run -s "-screen ${servernum} 1280x1024x24" ${FREESURFER_HOME}/bin/freeview -cmd ${fv_cmd}

# Crop images (make them narrower)
cd ${qcdir}
imsize=$(identify -format "%wx%h" ${fname})
imwidth=$(echo $imsize | awk -Fx '{print $1}')
cropwidth=$(( ${imwidth} / 2 ))
cropleft=$(( ${cropwidth} / 2 ))
imheight=$(echo $imsize | awk -Fx '{print $2}')
for im in slice_*_overlay.png; do
    convert ${im} -crop ${cropwidth}x${imheight}+${cropleft}+0 $(basename ${im} .png)_cropped.png
done
for im in slice_*_fa.png; do
    convert ${im} -crop ${cropwidth}x${imheight}+${cropleft}+0 $(basename ${im} .png)_cropped.png
done

# Combine the images into a single composite, and convert to "gif"
montage -geometry ${cropwidth}x${imheight} \
    *_overlay_cropped.png fa_overlay_${atlas_base}.png
convert -delay 1 -loop 1 *_overlay_cropped.png fa_overlay_${atlas_base}.gif
convert -delay 1 -loop 1 *_cropped.png alternating_overlay_${atlas_base}.gif
rm slice_*.png
