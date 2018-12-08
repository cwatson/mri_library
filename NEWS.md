# 2018-12-08

* Add a few CLI options for `eddy_quad`
* Add an error check for the `${target}_dicom.tar.gz` file

# 2018-11-12

## New files
* Moved the color variables to `globals.sh`; will be sourced by scripts for better usage messages
* `dicom2nifti.launcher.slurm` runs the first processing step for multiple subjects
* `eddy_cuda.slurm` runs `dti_eddy.sh` on *Lonestar5* for a single subject

## Removed files
* `fsl_qa_preproc.launcher.slurm` is no longer needed
* `preproc.slurm` is superseded by `dicom2nifti.slurm` and `eddy_cuda.slurm`
* The code from `dti_qc_eddy.sh` is now in `dti_eddy.sh`

## Minor changes
* `dti_dicom2nifti_bet.sh` now directly calls `dti_qc_bet.sh`

# 2018-11-06
* Use `cut` to get correct `jq` version info
* Remove backticks from `usage` functions

# 2018-11-05

* Added functions to log software, system, and parameter information in `json` files, using `jq` and `jo`

# 2018-11-04

## General updates
* Added a `LICENSE` file; using *Apache version 2.0*
* Added a script to hold "utility" functions, called `utilities.sh`
* Put error checking into its own script, `check_dependencies.sh`
* Changed the exit codes for non-trivial errors
* Added `${FSLDIR}/bin` in front of some FSL-based programs
* Changed the code to get `scriptdir` to work across more systems (e.g., `realpath` isn't available on *CentOS 6*)

# Other
* Added an *R* script, `slice_times.R`, to calculate the slice timing for interleaved acquisitions
    * Assume sequential acqusition for both *Philips* and *GE*

# 2018-10-23

* `dti_dicom2nifti_bet` now allows the specific input of the *DICOM* `.tar.gz` file, via the option `--tgz`.
    This means it is not required to have the `sourcedata` directory tree already set-up
* `dti_vars` will create `${srcdir}` if it doesn't exist, to facilitate the above change


# 2018-10-22
File renames and additions

* Removed the leading `fsl_` from the scripts, as it was redundant
* Initial preprocessing script no longer runs `eddy`
    * Created a separate `dti_eddy.sh` and `dti_qc_eddy.sh` since `eddy` is time-consuming
* Renamed the first *QC* script to `dti_qc_bet.sh`


# 2018-10-21
Overhaul of the preprocessing script

## General updates
* Remove the `--bids` option from all scripts; the project directory is now required to conform to the *BIDS* standard
* Initial commit of `README.md`
* Move atlas text files to `atlases` directory

## Preprocessing updates
* Now creates output directories if they don't already exist
* Gets `Manufacturer` info from the *DICOM* header
    * Extraction via `tar` now differs based on this; for *Philips* data, the directory structure is unchanged
    * For *GE* and *Siemens*, any leading directories are removed, and the files are extracted directly into `${srcdir}/tmp`
* Automatically calculate the number of `b0` images and average them together for `nodif.nii.gz`
* If `slspec.txt` doesn't exist, try to guess the slice timing information for *slice-to-volume* correction in `eddy_cuda`
    * For *Philips* data, hard-coded for sequential acquisition
* Change from `eddy_openmp` to `eddy_cuda`
    * Add `--mporder`, `--slspec`, `--residuals`, and `--cnr_maps` as arguments

# 2018-10-11
Move all files in `bin/fsl` up, to `bin/`.
