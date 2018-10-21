# 2018-10-21
Overhaul of the preprocessing script

## General updates
* Remove the `--bids` option from all scripts; the project directory is now required to conform to the *BIDS* standard
* Initial commit of `README.md`

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
