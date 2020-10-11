#! /bin/bash
# An example script for running all processing steps for DTI data.
#
# In this imaginary dataset, say there are multiple "acquisitions" but only 1 of
# interest. The labels/values will be
#     - subject ID:     s001
#     - session ID:     posttest
#     - acquisition:    multiband
#
# So, the initial NIfTI volume will be named:
#     sub-s001_ses-posttest_acq-multiband_dwi.nii.gz

# 1. Convert DICOM to NIfTI
dti_dicom2nifti_bet.sh -s s001 --long posttest --acq multiband --tgz s001_dicom.tar.gz

# 1a. Check if BET was successful. Re-run Step 1 if necessary.
# Manual
eog -f tractography/sub-s001/ses-posttest/dwi/qc/bet/*.png

# 2. Run eddy
dti_eddy.sh -s s001 --long posttest --acq multiband

# 2a. Check the `eddy_quad` outputs, to see if any data is unacceptable
# Manual

# 3. Run bedpostx
bedpostx tractography/sub-s001/ses-posttest/dwi

# 4. Register Freesurfer parcellation to diffusion space
dti_reg_FS_to_diff.sh -a dk.scgm -s s001 --long posttest --acq multiband

# 4a. Check registrations
# Manual

# 5. Run probtrackx2
dti_probtrackx2_run.sh -a dk.scgm -s s001 --long posttest --acq multiband \
    --pd --parallel

# 6. Create the network matrix from Step 5 outputs
fdt_network_matrix.sh -a dk.scgm -s s001 --long posttest --pd

# 7. Create networks of mean RD
dti_create_network.sh -a dk.scgm -s s001 --long posttest --acq multiband \
    -m RD --threshold 0.95
