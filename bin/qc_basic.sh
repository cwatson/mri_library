#! /bin/bash
# Chris Watson, 2019-02-23
set -a
source $(dirname "${BASH_SOURCE[0]}")/globals.sh

usage() {
    cat << !

 Perform basic QC for a given subject, modality, and session/acquisition (if
 applicable). It simply checks the image dimensions against expected values; the
 expected values for each modality should be in a text file under the ${myblue}sizes$(tput sgr0)
 directory. The naming scheme should be, e.g., ${myblue}dwi.sizes.txt$(tput sgr0). If the dimensions
 don't match, then the subject's data are moved to a ${myblue}unusable$(tput sgr0) directory, and no
 further processing is carried out.

 This is not meant to be called from the command line. It is called from within
 all initial modality-specific processing scripts, e.g.,
 "dti_dicom2nifti_bet.sh".

!
}

#-------------------------------------------------------------------------------
# Check dimensions of images; if they don't match, put into "unusable"
#-------------------------------------------------------------------------------
check_dims() {
    im=${projdir}/${rawdir}/${target}
    x=$(${FSLDIR}/bin/fslval ${im} dim1)
    y=$(${FSLDIR}/bin/fslval ${im} dim2)
    z=$(${FSLDIR}/bin/fslval ${im} dim3)
    t=$(${FSLDIR}/bin/fslval ${im} dim4)
    echo ${x} ${y} ${z} ${t}
}

size_file=${projdir}/data/sizes/${modality}.size.txt
if [[ -f ${size_file} ]]; then
    sz_study=$(cat ${size_file})
else
    echo "File ${size_file} does not exist."
    exit 73
fi
sz_sub=$(check_dims)
if [[ ${sz_sub} != ${sz_study} ]]; then
    echo "Subject ${subj} does not have correct dimensions"
    echo 'Moving data to "unusable" directory.'
    cd ${projdir}
    mkdir -p unusable/{${srcdir},${rawdir}}
    mv sourcedata/sub-${subj} unusable/sourcedata/
    mv rawdata/sub-${subj} unusable/rawdata/
    mv tractography/sub-${subj} unusable/tractography/
    exit 74
fi
