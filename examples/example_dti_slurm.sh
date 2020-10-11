#! /bin/bash
# An example script for running all processing steps for DTI data of all
# subjects, using Slurm (requiring the "launcher" utility).
#
# NOTE: Be sure to update the Slurm config parameters to fit your system!
#
# In this imaginary dataset, say there are multiple "acquisitions" but only 1 of
# interest. The labels/values will be
#     - subject IDs:    s001, s002, ...
#     - session ID:     posttest
#     - acquisition:    multiband
#
# So, the initial NIfTI volumes will be named:
#     sub-s001_ses-posttest_acq-multiband_dwi.nii.gz
#     sub-s002_ses-posttest_acq-multiband_dwi.nii.gz
#     ...

# The working directory should be the project directory
# Change the following variable to match your system
mri_lib=/home/cwatson/mri_library/slurm

# 1. Convert DICOM to NIfTI for all subjects for "posttest"
# NOTE: does not work with multiple "tgz" files
sbatch ${mri_lib}/dicom2nifti.launcher.slurm --long posttest --acq multiband \
    -- sourcedata/sub-s*

# 1a. Check if BET was successful. Re-run Step 1 if necessary.
# Manual
eog -f tractography/sub-s001/ses-posttest/dwi/qc/bet/*.png
eog -f tractography/sub-s002/ses-posttest/dwi/qc/bet/*.png
# etc.

# 2. Run eddy
for subj in tractography/sub-*; do
    sbatch ${mri_lib}/eddy_cuda.slurm \
        -s ${subj#*sub-} --long posttest --acq multiband
done

# 2a. Check the `eddy_quad` outputs, to see if any data is unacceptable
# Manual

# 2b. Run `eddy_squad`
# Assume there are 2 groups, with 12 subjects in each
cd tractography
echo "Groupings" >> groupings.txt
echo 0 >> groupings.txt
for i in {1..12}; do
    echo 0 >> groupings.txt
done
for i in {1..12}; do
    echo 1 >> groupings.txt
done
eddy_squad quad_folders.txt -g groupings.txt -u -o squad

# 3. Run bedpostx
for subj in tractography/sub-*; do
    sbatch ${mri_lib}/bedpostx_gpu.slurm \
        -s ${subj#*sub-} --long posttest --acq multiband
done

# 4. Register Freesurfer parcellation to diffusion space
# "posttest.txt" is a file with all subjects w/ valid posttest data
sbatch ${mri_lib}/dti_reg.launcher.slurm \
    -a dk.scgm --long posttest --acq multiband -- $(cat posttest.txt)

# 4a. Check registrations
# Manual

# 5. Run probtrackx2
# This example loops through all subjects, but this is a bad idea because it may
# tax the system too much (RE reading from and writing to disk)
while read subj; do
    subID=${subj##*sub-}
    sbatch ${mri_lib}/probtrackx2.launcher.slurm -a dk.scgm \
        -s ${subID} --long posttest --acq multiband --pd
done < posttest.txt

# 6. Create the network matrix from Step 5 outputs
sbatch ${mri_lib}/fdt_network_matrix.launcher.slurm \
    -a dk.scgm --long posttest --acq multiband --pd \
    -- $(cat posttest.txt)

# 7. Create networks of mean RD for all subjects
sbatch ${mri_lib}/dti_create_network.launcher.slurm \
    -a dk.scgm --long posttest --acq multiband --pd \
    -m RD --threshold 0.95 -- $(cat posttest.txt)
