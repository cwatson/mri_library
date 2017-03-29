#! /bin/bash
#
# Script to run DTI preprocessing with the new "eddy" tool. Assumes that the data
# have already been pulled from the archive file and "dcm2nii" (or similar) has
# already been run.
#_______________________________________________________________________________
# by Chris Watson, 2017-02-28

usage() {
    cat << !

    Preprocess DTI data using FSL's tools, including the new "eddy" tool.

    USAGE: $(basename $0) [options]

    OPTIONS:
        -h  Show this message
        -s  Subject ID
        -f  Intensity threshold for "bet" (default: 0.5)

    EXAMPLE:
        $(basename $0) -s SP7104_time1 -f 0.4

!
}

while getopts ":hs:f:" OPTION; do
    case $OPTION in
        s) subj="$OPTARG" ;;
        f) thresh="$OPTARG" ;;
        *) usage && exit ;;
    esac
done

[[ $# == 0 ]] && usage && exit
[[ ! -d ${subj} ]] && echo -e "Subject ${subj} is not valid!\n" && exit 3
[[ -z ${thresh} ]] && thresh=0.5

#-------------------------------------------------------------------------------
# Move all of the previous data to a separate directory; convert DICOMs
#-------------------------------------------------------------------------------
cd ${subj}
if [[ ! -d orig ]]; then
    mkdir orig
    mv dti2* orig/

    mkdir dti2
    ln -s $PWD/orig/dti2/dicom.tar.gz dti2
    cd dti2
else
    echo -e "\nThe 'orig' directory has already been created."
    echo -e "Check if preprocessing has already been completed."
    exit 4
fi

# The 34th volume is the ADC/trace. That's why 2 nifti images are created
tar zxf dicom.tar.gz
if [[ $(hostname) =~ .*stampede.* ]]; then
    ${WORK}/apps/mricrogl_lx/dcm2niix -z i -f dwi_orig -o . DICOM/
    eddycommand=eddy_cuda
else
    dcm2niix -z y -f dwi_orig -o . DICOM/
    eddycommand=eddy_openmp
fi
rm -r DICOM
mv dwi_orig.bvec bvecs.norot
mv dwi_orig.bval bvals

#-------------------------------------------------------------------------------
# Create files needed to run eddy; then run it
#-------------------------------------------------------------------------------
fslroi dwi_orig nodif 0 1
bet nodif{,_brain} -m -R -f ${thresh}
printf "0 1 0 0.0646" > acqparams.txt

nvols=$(fslnvols dwi_orig)
indx=""
for ((i=1; i<=${nvols}; i+=1)); do indx="$indx 1"; done
echo $indx > index.txt

mkdir eddy
echo -e '\n Running "eddy"!'
${eddycommand} \
    --imain=dwi_orig \
    --mask=nodif_brain_mask \
    --index=index.txt \
    --acqp=acqparams.txt \
    --bvecs=bvecs.norot \
    --bvals=bvals \
    --repol \
    --out=eddy/dwi_eddy
ln -s $PWD/eddy/dwi_eddy.nii.gz $PWD/data.nii.gz
ln -s $PWD/eddy/dwi_eddy.eddy_rotated_bvecs $PWD/bvecs

#-------------------------------------------------------------------------------
# Run dtifit
#-------------------------------------------------------------------------------
mkdir dtifit
dtifit -k data -m nodif_brain_mask -o dtifit/dtifit \
    -r bvecs -b bvals --sse --save_tensor
fslmaths dtifit/dtifit_L2 \
    -add dtifit/dtifit_L3 \
    -div 2 \
    dtifit/dtifit_RD
