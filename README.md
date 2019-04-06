# Scripts for processing brain MRI data
This library is a collection of *Bash* scripts, [Slurm](https://slurm.schedmd.com/)
scripts, and [R](https://www.r-project.org/) functions written for the processing
of *diffusion weighted imaging (DWI)* and *resting-state fMRI (rs-fMRI)* data.
The scripts start with just the raw *DICOM* images and perform steps up to network
creation, based on the results from
[probtrackx2](https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/FDT/UserGuide#PROBTRACKX_-_probabilistic_tracking_with_crossing_fibres)
for DWI and other methods for rs-fMRI.
The *Slurm* scripts are appropriate for use on a *high performance computing (HPC)* system/cluster;
I use the [Texas Advanced Computing Center (TACC)](https://www.tacc.utexas.edu/) systems.

The code has been written to work with projects following the
[Brain Imaging Data Structure (BIDS)](http://bids.neuroimaging.io/).
That is, if you only supply a `tar.gz` file with *DICOM* images, the appropriate
BIDS-compliant directories will be created.
Note that this only applies to inputs or minimal processing (e.g., conversion to *NIfTI*);
while there are some [BIDS Derivatives](http://bids.neuroimaging.io/#get_involved)
proposals, nothing has found consistent use (to my knowledge). So I place some
output directories which will be described later.

# Table of Contents
<!-- vim-markdown-toc GFM -->

* [Requirements](#requirements)
    * [Files/Formats and Directories](#filesformats-and-directories)
        * [DICOM files](#dicom-files)
        * [Basic QC](#basic-qc)
        * [Parcellations](#parcellations)
    * [Software](#software)
* [Installation](#installation)
    * [dcmtk](#dcmtk)
    * [dcm2niix](#dcm2niix)
    * [jo](#jo)
    * [jq](#jq)
    * [Xvfb](#xvfb)
    * [FSL](#fsl)
    * [Freesurfer](#freesurfer)
* [Processing Steps](#processing-steps)
    * [DWI](#dwi)
* [Variables](#variables)
* [Known Issues](#known-issues)
    * [Slice acquisition times](#slice-acquisition-times)
        * [GE](#ge)
    * [fslroi](#fslroi)
    * [FS to DTI registration script](#fs-to-dti-registration-script)

<!-- vim-markdown-toc -->
# Requirements
## Files/Formats and Directories
The *project directory* is where all scripts will be run from;
its variable is `${projdir}` and is automatically set as the working directory.
It is the *top-level* directory for your project; i.e., all relevant data should
be accessible from here.

### DICOM files
When running the initial scripts, you will need to provide one of the following:
1. A `sourcedata` directory, which contains *BIDS*-compliant subject directories
    and the *DICOM* files in `${target}_dicom.tar.gz` within that directory tree.
    In this case, you would *not* use the `--tgz` option to `dti_dicom2nifti_bet.sh`.

    Here, the `${target}` variable should follow the *BIDS* spec; for example
    (with optional information in square brackets):
    ``` bash
    sub-<studyID>[_ses-<sessionID>][_acq-<acquisition>]_dwi_dicom.tar.gz
    sub-<studyID>[_ses-<sessionID>]_task-rest[_acq-<acquisition>][_run-<runID>]_dicom.tar.gz
    ```

2. A `.tar.gz` that you provide as input to the initial script, `dti_dicom2nifti_bet.sh`.
    This `.tar.gz` file *MUST* be either directly in `${projdir}` or you must provide the full path.
    This will be renamed to `${target}_dicom.tar.gz` (see above) and placed under the `sourcedata` directory.

### Basic QC
To perform the most basic QC check &mdash; checking that image dimensions match &mdash;
there must be a simple text file for each acquisition.

For example, if your DWI acquisition matrix is `96 x 96`, there are 65 slices,
and 32 diffusion-weighted volumes + 1 non-diffusion weighted volume:
``` bash
cat ${projdir}/data/sizes/dwi_size.txt
96 96 65 33
```

If the files do not exist, the initial script will exit with an error.
If the files do exist, and the dimensions do *not* match, the data will be moved to the `${projdir}/unusable` directory.

### Parcellations
Subject-specific parcellations will be used as the sources/targets of the network (at least for DTI tractography).
The results from *Freesurfer*'s `recon-all` should be in `${projdir}/freesurfer`.

## Software
In addition to good-quality T1-weighted and DWI data, some software requirements are:

* [`dcmtk`](https://dicom.offis.de/dcmtk.php.en) for reading from the *DICOM* headers
* A recent version of [`dcm2niix`](https://www.nitrc.org/plugins/mwiki/index.php/dcm2nii:MainPage)
    * The version I used at the time of writing is `v1.0.20181125  GCC4.8.5 (64-bit Linux)`
* [`jo`](https://github.co/jpmens/jo) for writing out *JSON* files containing the parameters used for each tool.
    For example, it will record the `-f` value used with `bet`.
* [`jq`](https://stedolan.github.io/jq) also processes *JSON* files.
* [FSL](https://fsl.fmrib.ox.ac.uk/fsl/fslwiki) version >= *6.0.0*
* The [ImageMagick suite](https://www.imagemagick.org/script/index.php)
    * Available in the repositories for *Red Hat*-based systems (*RHEL*, *CentOS*, *Scientific Linux*)
* `Xvfb`, the X Virtual Frame Buffer
* [`eddyqc`](https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/eddyqc) (bundled with *FSL* since *v6.0.0*)
* [Freesurfer](https://surfer.nmr.mgh.harvard.edu/) version >= *5.3.0*
    * Required for parcellation, the results of which will be used in the tractography step
* [R](https://cran.r-project.org/) is required for `eddy`-related movement QC. `R` is available on all major OS's. Necessary packages include:
    * [optparse](https://cran.r-project.org/web/packages/optparse/index.html)
    * [data.table](https://cran.r-project.org/web/packages/data.table/index.html)
    * [ggplot2](https://cran.r-project.org/web/packages/ggplot2/index.html)
    * [gridExtra](https://cran.r-project.org/web/packages/gridExtra/index.html)
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

If you are on a cluster or other system that uses, e.g., `.bashrc` instead, you may have to add the path manually.

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
To install it, follow the instructions on the [jo repository page](https://github.com/jpmens/jo).
You will also need [`automake`](https://www.gnu.org/software/automake) and [`autoconf`](https://www.gnu.org/software/autoconf).
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

## Xvfb
There should be a package readily available on most systems. On `CentOS`, it is called `xorg-x11-server-Xvfb`.

## FSL
To install the latest version of *FSL* (which is *v6.0.0* as of October 2018), you simply run their installer.
This requires that you already have an older version of *FSL* on your system.
``` bash
cd ${FSLDIR}
python fslinstaller.py
```

## Freesurfer
You can find download and install instructions at the [Freesurfer wiki](https://surfer.nmr.mgh.harvard.edu/fswiki/DownloadAndInstall).

# Processing Steps
## DWI
The scripts will perform the following steps. *Freesurfer*'s `recon-all` should be run before this (or before step 5, at least).
1. Run `dti_dicom2nift_bet.sh` to extract *DICOM* files and convert to *NIfTI* using `dcm2niix`, skullstrip, and create images for QC purposes.
    <ol type="a">
    <li>Renames and moves the <code>tgz</code> file to the correct, <em>BIDS</em>-compatible filename and location (if necessary)</li>
    <li>Extracts the <em>DICOM</em> files from the <code>tgz</code> file and convert to <em>NIfTI</em> (using <code>dcm2niix</code>) </li>
    <li>Moves the <code>nii.gz</code>, <code>bvecs</code>, <code>bvals</code>, and <code>json</code>
        files to the appropriate subject directory under <code>rawdata</code>.</li>
    <li>Checks the image dimensions against the study's dimensions (specified by the user in a text file) via <code>qc_basic.sh</code>. If this fails, the subject's data are moved to a directory called <code>unusable</code>.</li>
    <li>If there are multiple <em>b0</em> volumes, they will be averaged when creating <code>nodif.nii.gz</code></li>
    <li>Skullstrips the data using <a href="https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/BET/UserGuide"><code>bet</code></a>.</li>
    <li>Runs <code>dti_qc_bet.sh</code> to generate screenshots of the skullstripped data.
        See <a href="https://imgur.com/a/rkxkgV4">example images</a>.</li>
    </ol>

    ``` bash
    dti_dicom2nifti_bet.sh -s s001 --acq multishell --tgz s001_dicom.tar.gz
    # Creates the files:
    ${projdir}/rawdir/sub-s001/dwi/sub-s001_acq-multishell_dwi.{nii.gz,bval,bvec,json}
    # Creates the directory:
    ${projdir}/tractography/sub-s001/dwi/qc_bet/
    ```
2. (manual) Check the quality of `bet` by viewing the images in `${resdir}/qc/bet`.
    <ol type="a">
    <li>Re-run <em>Step 1</em> if the skullstrip wasn't acceptable.
        Do this by passing the <code>--rerun</code> and <code>-t|--threshold</code> options
        to <code>dti_dicom2nifti_bet.sh</code>.</li>
    </ol>

    For example,
    ``` bash
    eog tractography/sub-s001/dwi/qc/bet/*.png
    dti_dicom2nifti_bet.sh -s s001 --acq multishell --rerun -t 0.4
    ```

3. Run `eddy` via `dti_eddy.sh`.
    <ol type="a">
    <li>Also calculates <code>eddy</code>-specific QC metrics via <code>eddy_quad</code> from
        <a href="https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/eddyqc"><code>eddyqc</code></a>.</li>
    </ol>

    ``` bash
    dti_eddy.sh -s s001 -acq multishell
    ```
4. If you *do not* have a GPU but *do* have a *SLURM* scheduler, run *BEDPOSTX* via `dti_bedpostx_run.sh`.
    <ol type="a">
    <li>You will then also need to run <code>dti_bedpostx_postproc.sh</code>.</li>
    <li>If you <em>do</em> have a GPU, you can run <code>bedpostx_gpu</code> on <code>${projdir}/${resdir}</code>.</li>
    <li>If you have a system with an <em>SGE</em> scheduler, you can run <code>bedpostx</code> normally.</li>
    </ol>
5. Run the setup script `dti_reg_FS_to_diff.sh` to register the Freesurfer parcellation to diffusion space.
6. Check the quality of the registration/parcellation by viewing the images produced from *Step 5*.
See <a href="https://imgur.com/bAZorVZ">an example image</a>.
7. Run the tractography via `dti_probtrackx2_run.sh`.
You can choose to use the GPU version, or you can run it in parallel (which requires `GNU parallel`.
8. Create connectivity matrices in which the entries are the estimated streamline counts between all region pairs,
using the `R` script `fsl_fdt_matrix.R`. This creates a file called `fdt_network_matrix`
(assuming you haven't already run `probtrackx2` in *network* mode).
9. Create connectivity matrices in which the entries are the mean of some microstructural measure (e.g., *FA*) along
the top `N`% of streamlines. The default is to use the top 10%.

# Variables
The following variables are exported by `setup_vars.sh` and are used to create the
appropriate directory and filename targets that conform to the *BIDS* standard
See the code block following the list for examples.

<dl>
    <dt>projdir</dt>
    <dd>The project's top-level directory. All preprocessing scripts <b>must</b> be called from this directory.</dd>
    <dt>target</dt>
    <dd>The character string for the subject (plus the session and acquisition, if applicable).<br/>
        Directories and filenames will both be generated using this variable.</dd>
    <dt>srcdir</dt>
    <dd>The directory that holds the "source" data.
        Here, "source" indicates data that came directly from the scanner;
        i.e., DICOM files, PAR/REC files (for Philips data), Siemens mosaic, etc.</dd>
    <dt>rawdir</dt>
    <dd>The directory that will hold the "raw" data.
        Here, "raw" simply indicates that no preprocessing has been applied to them.</dd>
    <dt>fs_sub_dir</dt>
    <dd>The name of the directories containing <em>Freesurfer</em> results.
        Since Freesurfer's <code>SUBJECTS_DIR</code> is "flat" (i.e., all data must be in a single directory),
        if the study is longitudinal then the <code>_ses-${session}</code> will be in the directory names.</dd>
    <dt>resdir</dt>
    <dd>The directory where results will be stored. For DWI data, this will be <code>${projdir}/tractography</code>
        (containing the results from both <code>bedpostx</code> and <code>probtrackx2</code>).</dd>
</dl>

For example, in a theoretical test-retest study, the outputs might look like the following.
The directories live directly under `${projdir}`.
``` bash
${target}       sub-s001_ses-retest_acq-highres_T1w
                sub-s001_ses-retest_acq-multishell_dwi
                sub-s001_ses-retest_task-rest_bold

${srcdir}       sourcedata/sub-s001/ses-retest/{anat,dwi,func}
                    `- ${target}_dicom.tar.gz
${rawdir}       rawdata/sub-s001/ses-retest/dwi
                    `- ${target}.{bvals,bvecs,json,nii.gz}
${resdir}       tractography/sub-s001/ses-retest/dwi
${fs_sub_dir}   freesurfer/sub-s001_ses-retest
```

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

## fslroi
In FSL *v6.0.0*, `fslroi` has undesired behavior; for some files, it remapped voxel values so that the `nodif` images were completely wrong. A temporary workaround is to use `fslmaths` to change the image type of `dwi_orig.nii.gz` to *float*. This bug should be fixed in *v6.0.1*.

## FS to DTI registration script
The QC script for Freesurfer to diffusion space relies on `xvfb-run`.
The argument `-n` allows you to specify a specific *server number*, but sometimes this still results in errors.
The SLURM script (`dti_reg.launcher.slurm`) will automatically increment this from 0 for each subject,
but if you have more than 100 subjects processed at once, there might be an error.
