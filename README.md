# Scripts for processing brain MRI data
This library is a collection of *Bash* and [Slurm](https://slurm.schedmd.com/)
scripts (plus one [R](https://www.r-project.org/) function) written for the
processing of *diffusion weighted imaging (DWI)* and *resting-state fMRI (rs-fMRI)* data. The scripts start with
just the raw *DICOM* images and perform steps up to network creation, based on the results from
[probtrackx2](https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/FDT/UserGuide#PROBTRACKX_-_probabilistic_tracking_with_crossing_fibres) for DWI
and other methods for rs-fMRI.

The code has been written to work with projects following the [Brain Imaging Data Structure (BIDS)](http://bids.neuroimaging.io/).
That is, if you only supply a `tar.gz` file with *DICOM* images, the appropriate BIDS-compliant directories will be created.
Note that this only applies to inputs or minimal processing (e.g., conversion to *NIfTI*);
while there are some [BIDS Derivatives](http://bids.neuroimaging.io/#get_involved)
proposals, nothing has found consistent use (to my knowledge). So I place some output directories which will be described later.

# Table of Contents
<!-- vim-markdown-toc GFM -->

* [Requirements](#requirements)
    * [Files/Formats and Directories](#filesformats-and-directories)
        * [Parcellations](#parcellations)
    * [Software](#software)
* [Installation](#installation)
    * [FSL](#fsl)
    * [dcmtk](#dcmtk)
    * [dcm2niix](#dcm2niix)
    * [jo](#jo)
    * [jq](#jq)
* [Processing Steps](#processing-steps)
    * [DWI](#dwi)
* [Variables](#variables)
* [Known Issues](#known-issues)
    * [Slice acquisition times](#slice-acquisition-times)
        * [GE](#ge)

<!-- vim-markdown-toc -->
# Requirements
## Files/Formats and Directories
The *project directory* is where all scripts will be run from; its variable is `${projdir}`.
It is the *top-level* directory for your project; i.e., all relevant data should be accessible from here.

When running the initial scripts, you will need to provide 1 of the following:
1. A `sourcedata` directory, which contains *BIDS*-compliant subject directories
    and the *DICOM* files in `${target}_dicom.tar.gz` within that directory tree.

    Here, the `${target}` variable should follow the *BIDS* spec; for example
    (with optional information in square brackets):
    ``` bash
    sub-<studyID>[_ses-01][_acq-multishell]_dwi_dicom.tar.gz
    sub-<studyID>[_ses-01]_task-rest[_acq-multiband][_run-01]_dicom.tar.gz`
    ```
    In this case, you do not have to use the `--tgz` option to `dti_dicom2nifti_bet.sh`.
2. A `tar.gz` that you provide as input to the initial script, `dti_dicom2nifti_bet.sh`.
    This file *MUST* be directly in `${projdir}`, or you must provide the full path.
    This will be renamed to `${target}_dicom.tar.gz` (see above) and placed under the `sourcedata` directory.

### Parcellations
Subject-specific parcellations will be used as the sources/targets of the network (at least for DTI tractography).
The results from *Freesurfer*'s `recon-all` should be in `${projdir}/freesurfer`.
The subject directories (within `freesurfer`) should at least share the same directory name as those in `sourcedata`.

## Software
In addition to good-quality T1-weighted and DWI data, some software requirements are:

* [`dcmtk`](https://dicom.offis.de/dcmtk.php.en) for reading from the *DICOM* headers
* [`jo`](https://github.co/jpmens/jo) for writing out *JSON* files containing the parameters used for each tool.
    For example, it will record the `-f` value used with `bet`.
* [`jq`](https://stedolan.github.io/jq) also processes *JSON* files.
* A recent version of [`dcm2niix`](https://www.nitrc.org/plugins/mwiki/index.php/dcm2nii:MainPage)
    * The version I used at the time of writing is `v1.0.20181013  GCC4.8.5 (64-bit Linux)`
* [FSL](https://fsl.fmrib.ox.ac.uk/fsl/fslwiki) version >= *6.0.0*
* The [ImageMagick suite](https://www.imagemagick.org/script/index.php)
    * Available in the repositories for *Red Hat*-based systems (*RHEL*, *CentOS*, *Scientific Linux*)
* [`eddyqc`](https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/eddyqc) (bundled with *FSL* since *v6.0.0*)
* [Freesurfer](https://surfer.nmr.mgh.harvard.edu/) version >= *5.3.0*
    * Required for parcellation, the results of which will be used in the tractography step
* (*Optional*) A [CUDA](https://developer.nvidia.com/cuda-zone)-capable GPU
  (for [`eddy_cuda`](https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/eddy/UsersGuide) and
  [`bedpostx_gpu`](https://users.fmrib.ox.ac.uk/~moisesf/Bedpostx_GPU/))
    * If you don't have this, you can use `eddy_openmp` and the regular `bedpostx` instead;
        you'll have to change the code accordingly.
    * To run `bedpostx` on a *SLURM* system without a GPU, you will need the [`launcher`](https://github.com/TACC/launcher) utility

# Installation
You can simply clone the repository and add it to your search path. Example:

``` bash
git clone https://github.com/cwatson/mri_library.git
echo "export PATH=PATH:${PWD}/mri_library/bin" >> ~/.bash_profile
```

## FSL
To install the latest version of *FSL* (which is *v6.0.0* as of October 2018), you simply run their installer.
This requires that you already have an older version of *FSL* on your system.
``` bash
cd ${FSLDIR}
python fslinstaller.py
```

## dcmtk
For *CentOS 7*, at least, this is available in the `nux-dextop` repository. If you don't already have this repo, run the following as `root`:
``` bash
yum -y install http://li.nux.ro/download/nux/dextop/el7/x86_64/nux-dextop-release-0-5.el7.nux.noarch.rpm
yum install dcmtk\*
```
The version I use at the time of writing is `v3.6.0`.

If you are on *Debian*: `sudo apt install dcmtk`.

For other systems, you will probably have to install from source.
See [the DCMTK site](https://dicom.offis.de/dcmtk.php.en) for more information.

## dcm2niix
I prefer to clone the *Github* repository.
``` bash
cd /usr/local
git clone git://github.com/rordenlab/dcm2niix.git
cd dcm2niix
mkdir build && cd build
cmake ..
make install
```

## jo
This utility can generate *JSON* from the command line.
To install it, follow the instructions on the [repository page](https://github.com/jpmens/jo).
(you will also need [`automake`](https://www.gnu.org/software/automake) and [`autoconf`](https://www.gnu.org/software/autoconf) ).
``` bash
cd /usr/local
git clone git://github.com/jpmens/jo.git
cd jo
autoreconf -i
./configure
make check
make install
```
If you are running `CentOS 6`, you will have to install the `autoconf268` package, and then call `autoreconf268` instead.

## jq
This should be in repositories for all major Linux OS's.
For both *CentOS 6* and *CentOS 7*, it is in the `epel` repository,
with versions `v1.3.2` and `v1.5.1`, respectively.

# Processing Steps
## DWI
The scripts will perform the following steps. *Freesurfer*'s `recon-all` should be run before this (or before step 5, at least).
1. Run `dti_dicom2nift_bet.sh` to extract *DICOM* files and convert to *NIfTI* using `dcm2niix`, skullstrip, and create images for QC purposes.
    <ol type="a">
    <li>Moves the <code>nii.gz</code>, <code>bvecs</code>, <code>bvals</code>, and <code>json</code>
        files to the appropriate subject directory under <code>rawdata</code>.</li>
    <li>If there are multiple <em>b0</em> volumes, they will be averaged when creating <code>nodif.nii.gz</code></li>
    <li>Skullstrips the data using <a href="https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/BET/UserGuide"><code>bet</code></a>.</li>
    <li>Checks the quality by running <code>dti_qc_bet.sh</code> and viewing the resultant images.
        See <a href="https://imgur.com/a/rkxkgV4">example images</a>.</li>
    <li>Re-run if the skullstrip wasn't acceptable; change the <code>bet</code> threshold by passing
        the <code>--rerun</code> and <code>-t</code>/<code>--threshold</code> options to <em>Step 1</em>.</li>
    </ol>

    ``` bash
    dti_dicom2nifti_bet.sh -s sub01 --acq multishell --tgz sub01_dicom.tar.gz
    # Creates the files:
    ${projdir}/rawdir/sub-sub01/dwi/sub-sub01_acq-multishell_dwi.{nii.gz,bval,bvec,json}
    # Creates the directory:
    ${projdir}/tractography/sub-sub01/dwi/qc_bet/
    ```
2. Run `eddy` via `dti_eddy.sh`.
    <ol type="a">
    <li>Also calculates <code>eddy</code>-specific QC metrics via <code>eddy_quad</code> from
        <a href="https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/eddyqc"><code>eddyqc</code></a>.</li>
    </ol>

    ``` bash
    dti_eddy.sh -s sub01 -acq multishell
    ```
3. If you *do not* have a GPU but *do* have a *SLURM* scheduler, run *BEDPOSTX* via `dti_bedpostx_run.sh`.
    <ol type="a">
    <li>You will then also need to run <code>dti_bedpostx_postproc.sh</code>.</li>
    <li>If you <em>do</em> have a GPU, you can run <code>bedpostx_gpu</code> on <code>${projdir}/${resdir}</code>.</li>
    <li>If you have a system with an <em>SGE</em> scheduler, you can run <code>bedpostx</code> normally.</li>
    </ol>
4. Run the setup script `dti_probrackx2_setup.sh`.
5. Check the quality of the registration/parcellation by running `dti_qc_probtrackx2.sh`.

# Variables
These variables are created in `dti_vars.sh` and are primarily used (by `dti_dicom2nifti_bet.sh`)
to create the appropriate directories and files with the correct names.

* `projdir` The project's top-level directory. All preprocessing scripts should be called from this directory.
* `target` The character string for the subject (plus the session and acquisition, if applicable).
    * For example, this might be `sub-SP7102_ses-01_acq-iso_dwi` in the case of > 1 session and > 1 DWI acquisition.
    * Directories and filenames will both be generated using this variable.
* `rawdir` The directory (which lives under `${projdir}/rawdata` that will hold the "raw" data.
    Here, "raw" simply indicates that no preprocessing has been applied to them.
    * In the DWI case, this will contain `nii.gz` volume(s), `bvecs`, `bvals`, and a *JSON* file
        (also called a "BIDS sidecar", created by `dcm2niix`).
* `srcdir` The directory (which lives under `${projdir}/sourcedata`) that holds the "source" data.
    Here, "source" indicates data that came directly from the scanner:
    DICOM files, PAR/REC files (for Philips data), Siemens mosaic, etc.
* `resdir` The directory where results will be stored.
    For DWI data, this will be `${projdir}/tractography` (containing the results from both `bedpostx` and `probtrackx2`).

# Known Issues
## Slice acquisition times
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

