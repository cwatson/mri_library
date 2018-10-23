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
