#! /bin/bash
#
# Script to run DTI preprocessing with the new "eddy" tool. Assumes that the data
# have already been pulled from the archive file and "dcm2nii" (or similar) has
# already been run.
#_______________________________________________________________________________
# by Chris Watson, 2017-02-28

usage()
{
    cat << !

    Preprocess DTI data using FSL's tools, including the new "eddy" tool.

    USAGE: $(basename $0) [options]

    OPTIONS:
        -h      Show this message
        -s      Subject ID

    EXAMPLE:
        $(basename $0) -s SP7104_time1

!
}

while getopts ":hm:s:t:" OPTION
do
    case $OPTION in
        h)
            usage
            exit 1
            ;;

        s)
            subj="$OPTARG"
            ;;

        *)
            usage
            exit 99
            ;;
    esac
done

if [ $# == 0 ]; then
    usage
    exit 2
fi

if [[ ! -d ${subj} ]]; then
    echo -e "Subject ${subj} is not valid!\n"
    exit 3
fi

# Move all of the previous data to a separate directory
cd ${subj}
if [[ ! -d orig ]]; then
    mkdir orig
    mv dti2* struct orig

    mkdir dti2
    ln -s $PWD/orig/dti2/dicom.tar.gz dti2
    cd dti2
fi

# The 34th volume is the ADC/trace. That's why 2 nifti images are created
tar zxf dicom.tar.gz
#scale_factor=$(dcmdump +P "2005,100e" DICOM/IM_0001 | awk '{print $3}')
#dcm2niix -f dwi_orig ./*.PAR
dcm2niix -z y -f dwi_orig -o . DICOM/
mv dwi_orig.bvec bvecs.norot
mv dwi_orig.bval bvals
#fslmaths dwi_orig -mul ${scale_factor} dwi_orig_scaled

fslroi dwi_orig nodif 0 1
bet2 nodif{,_brain} -m
printf "0 1 0 0.0646" > acqparams.txt

nvols=$(fslnvols dwi_orig)
indx=""
for ((i=1; i<=${nvols}; i+=1)); do indx="$indx 1"; done
echo $indx > index.txt

mkdir eddy
echo -e '\n Running "eddy"!'
eddy_openmp \
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

mkdir dtifit
dtifit -k data -m nodif_brain_mask -o dtifit/dtifit \
    -r bvecs -b bvals --sse --save_tensor
fslmaths dtifit/dtifit_L2 \
    -add dtifit/dtifit_L3 \
    -div 2 \
    dtifit/dtifit_RD
