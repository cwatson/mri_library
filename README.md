# Scripts for processing Diffusion Weighted Imaging data
This library is a collection of *Bash* and [Slurm](https://slurm.schedmd.com/)
scripts (plus one [R](https://www.r-project.org/) function) written for the
processing of *diffusion weighted imaging (DWI)* data. The scripts start with
just the raw *DICOM* images and performs steps up to network creation (based on the results from
[probtrackx2](https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/FDT/UserGuide#PROBTRACKX_-_probabilistic_tracking_with_crossing_fibres).

The code has been written to work with projects following the [Brain Imaging Data Structure (BIDS)](http://bids.neuroimaging.io/).
Note that this only applies to inputs; there are some [BIDS Derivatives](http://bids.neuroimaging.io/#get_involved)
proposals, but nothing has found consistent use (to my knowledge).

# Table of Contents
<!-- vim-markdown-toc GFM -->

* [Installation](#installation)
* [Requirements](#requirements)
    * [Files/Formats](#filesformats)
    * [Software](#software)
    * [Scanner vendor issues](#scanner-vendor-issues)
        * [GE](#ge)
* [Processing Steps](#processing-steps)
* [Variables](#variables)

<!-- vim-markdown-toc -->

# Installation
You can simply clone the repository and add it to your search path. Example:

``` bash
git clone https://github.com/cwatson/mri_library.git
echo "PATH=PATH:${PWD}/mri_library/bin" >> ~/.bash_profile
```

# Requirements
## Files/Formats
* The project directory should contain `sourcedata`, which underneath contains *BIDS*-compliant subject directories.
* The scripts expect the DWI data to be in a file called `${target}_dicom.tar.gz`.
    Here, `${target}` should follow the *BIDS* spec; for example (with optional information in square brackets):
    `sub-{studyID}_[ses-01_acq-multishell]_dwi_dicom.tar.gz`
    * If there are multiple *b0* volumes, they will be averaged when creating `nodif.nii.gz`
* The parcellations should be in `freesurfer`, which is in the project directory.
    The subject directories should at least share the same directory name as those in
    `sourcedata`.

## Software
In addition to good-quality T1-weighted and DWI data, some software requirements are:

* [dcmtk](https://dicom.offis.de/dcmtk.php.en) for reading from the *DICOM* headers
    * Available in *CentOS* repos, and likely other distributions
* A recent version of [dcm2niix](https://www.nitrc.org/plugins/mwiki/index.php/dcm2nii:MainPage)
    * The version I used at the time of writing is `v1.0.20181013  GCC4.8.5 (64-bit Linux)`
* [FSL](https://fsl.fmrib.ox.ac.uk/fsl/fslwiki) version >= *5.0.11*
* [eddyqc](https://git.fmrib.ox.ac.uk/matteob/eddy_qc_release)
    * Until it is bundled with *FSL*, you can clone the repo at the above URL
    * See also the [eddyqc wiki page](https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/eddyqc)
* [Freesurfer](https://surfer.nmr.mgh.harvard.edu/) version >= *5.3.0*
    * Required for parcellation, the results of which will be used in the tractography step
* (*Optional*) A [CUDA](https://developer.nvidia.com/cuda-zone)-capable GPU
  (for [eddy_cuda](https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/eddy/UsersGuide) and
  [bedpostx_gpu](https://users.fmrib.ox.ac.uk/~moisesf/Bedpostx_GPU/))
    * If you don't have this, you can use `eddy_openmp` and the regular `bedpostx` instead;
        you'll have to change the code accordingly.
    * To run `bedpostx` on a *SLURM* system without a GPU, you will need the [launcher](https://github.com/TACC/launcher) utility

## Scanner vendor issues
It seems that *GE* and *Philips* do not record the `SliceTiming` information
which is necessary for `eddy`'s *slice-to-volume* motion correction.
There isn't a foolproof way of getting this information, aside from at the scanner console itself.

### GE
From [this thread](https://neurostars.org/t/dcm2nii-problem-with-slice-timing-metadata-extraction/1922/6),
helpful *DICOM* tags are:
* `0020,1002` `ImagesInAcquisition` -- should be equal for all in a single acquisition
* `0020,9057` `InStackPositionNumber` -- the slice number for each volume
* `0020,0013` `InstanceNumber` -- slice number in the whole acquisition
* `0020,1041` `SliceLocation`

That thread links to [another thread](https://neurostars.org/t/getting-missing-ge-information-required-by-bids-for-common-preprocessing/1357/4)
which references some more *DICOM* tags, and links to a [Github repo](https://github.com/nikadon/cc-dcm2bids-wrapper)
that may be able to find out this information.


# Processing Steps
The scripts will perform the following steps. *Freesurfer*'s `recon-all` should be run before this (or before step 5, at least).
1. Run `dti_dicom2nift_bet.sh` to extract *DICOM* files and convert to *NIfTI* using `dcm2niix`.
    1. Moves the `NIfTI`, `bvecs`, `bvals`, and `json` files to under `rawdata`.
2. Skullstrip the data using `bet` (same script as in #1).
3. Check the quality by running `dti_qc_bet.sh` and viewing the images.
    1. Re-run if the skullstrip wasn't acceptable; change the `bet` threshold by passing the `-t` or `--threshold` argument.
4. Run `eddy` via `dti_eddy.sh`.
5. Run `eddyqc` via `dti_qc_eddy.sh`.
6. If you don't have a GPU but *do* have a *SLURM* scheduler, run *BEDPOSTX* via `dti_bedpostx_run.sh`.
    1. You will then also need to run `dti_bedpostx_postproc.sh`.
    2. If you do have a GPU, you can run `bedpostx_gpu` yourself.
    3. If you have a system with an *SGE* scheduler, you can run `bedpostx` normally.
7. Run the setup script `dti_probrackx2_setup.sh`.
8. Check the quality of the registration/parcellation by running `dti_qc_probtrackx2.sh`.

# Variables
These variables are created in `fsl_dti_vars.sh` and are primarily used (by `fsl_dti_preproc.sh`)
to create the appropriate directories and files with the correct names.

* `projdir` The project's top-level directory. All preprocessing scripts should be called from this directory.
* `target` The character string for the subject (and session, if applicable).
    For example, this might be `sub-SP7102_ses-01_acq-iso_dwi` in the case of > 1 session and > 1 DWI acquisition.
    Directories and filenames will both be generated using this variable.
* `rawdir` The directory (which lives under `${projdir}/rawdata` that will hold the "raw" data.
    Here, "raw" simply indicates that no preprocessing has been applied to them.
    In the DWI case, this will contain `nii.gz` volume(s), `bvecs`, `bvals`, and JSON file (created by `dcm2niix`).
* `srcdir` The directory (which lives under `${projdir}/sourcedata`) that holds the "source" data.
    Here, "source" indicates data that came directly from the scanner:
    DICOM files, PAR/REC files (for Philips data), Siemens mosaic, etc.
* `resdir` The directory (which lives under `${projdir}/tractography`)
    where both `bedpostx` and `probtrackx2` results will be stored.
