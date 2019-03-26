#! /bin/bash
# Chris Watson, 2019-03-25
set -a

usage() {
    cat << !

 Calculate some QC metrics for DWI data. These were taken from the Preprocessed
 Connectomes Project (PCP)'s "Quality Assessment Protocol (QAP)"; see details at
 https://preprocessed-connectomes-project.org/quality-assessment-protocol/

    1. Temporal signal-to-noise (tSNR): mean divided by standard deviation of
       within-mask voxels across all DWI volumes.
    2. SNR: mean of within-mask voxels divided by standard deviation of
       non-brain voxels. Higher is better.
    3. Number of eddy outliers
    4. Mean frame displacement (FD)
    5. Root-mean-square (RMS) of FD
    6. Number of outliers based on FD (using a cutoff of 0.5mm)
    7-9. RMS of translations, rotations, and translations & rotations combined

!
}

# 1. tSNR
#-------------------
${mathcommand[@]} data -Tmean mean
${mathcommand[@]} data -Tstd std
${mathcommand[@]} mean -div std tsnr
${mathcommand[@]} tsnr -mas nodif_brain_mask tsnr_mask
tsnr_mean=$(${statcommand[@]} tsnr_mask -l 0 -M)

# 2. SNR
#-------------------
${mathcommand[@]} nodif_brain -binv background
${mathcommand[@]} nodif -mas background nodif_background
b0_mean=$(${statcommand[@]} nodif_brain -M)
bg_std=$(${statcommand[@]} nodif_background -S)
snr_mean=$(echo "${b0_mean} / ${bg_std}" | bc -l)

# 3. # of eddy outliers
#-------------------
n_outl_eddy=$(wc -l eddy/dwi_eddy.eddy_outlier_report | awk '{print $1}')


# Run R script to get movement-related parameters
#-------------------------------------------------------------------------------
cd ${projdir}
Rscript ${scriptdir}/dti_qc_eddy.Rscript -s ${subj} --long ${sess} --fd-cutoff ${fd}
cd ${resdir}

# 4. Mean FD
#-------------------
mean_fd=$(cat qc/eddy/frame_displacement_mean.txt)

# 5. RMS of FD
#-------------------
rms_fd=$(cat qc/eddy/frame_displacement_rms.txt)

# 6. # of FD outliers
#-------------------
n_outl_fd=$(cat qc/eddy/frame_displacement_numOutliers.txt)

# 7-9. RMS translation, rotation, and all
#-------------------
rms_xyz=$(cat qc/eddy/rms_translation.txt)
rms_rot=$(cat qc/eddy/rms_rotation.txt)
rms_all=$(cat qc/eddy/rms_all.txt)

# Write to file
#-------------------------------------------------------------------------------
qc_file=${projdir}/tractography/qc.csv
if [[ ! -f ${qc_file} ]]; then
    header_str="Study.ID"
    if [[ ${long} -eq 1 ]]; then
        header_str="${header_str},Time"
    fi
    header_str="${header_str},Variable,Value"
    echo ${header_str} >> ${qc_file}
fi

start_str="${subj}"
if [[ ${long} -eq 1 ]]; then
    start_str="${start_str},${sess}"
fi

echo "${start_str},dwi_tsnr,${tsnr_mean}" >> ${qc_file}
echo "${start_str},dwi_snr,${snr_mean}" >> ${qc_file}
echo "${start_str},dwi_numOutliers_eddy,${n_outl_eddy}" >> ${qc_file}
echo "${start_str},dwi_mean_FD,${mean_fd}" >> ${qc_file}
echo "${start_str},dwi_rms_FD,${rms_fd}" >> ${qc_file}
echo "${start_str},dwi_numOutliers_FD,${n_outl_fd}" >> ${qc_file}
echo "${start_str},dwi_rms_xyz,${rms_xyz}" >> ${qc_file}
echo "${start_str},dwi_rms_rot,${rms_rot}" >> ${qc_file}
echo "${start_str},dwi_rms_all,${rms_all}" >> ${qc_file}
