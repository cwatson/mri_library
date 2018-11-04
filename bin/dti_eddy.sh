#! /bin/bash
# Chris Watson, 2017-02-28
set -a

usage() {
    cat << !

 Setup and run 'eddy' on DTI data. If you do not have "acqparams.txt",
 "index.txt", or "slspec.txt" files in ${resdir}, then generic ones will be
 created (with values from the FSL wiki). If you have files that apply to all
 study subjects, you can pass those in via function arguments; these should be
 located in the ${projdir} (where the script is called from).

 USAGE:
    $(basename $0) [-s SUBJECT] [--long SESSION] [--acq LABEL] [--params FILE]
    [--index FILE] [--mp MPORDER] [--slspec FILE]

 OPTIONS:
     -h, --help
         Show this message

     -s, --subject [SUBJECT]
         Subject ID. This will be the "label" in the directories and filenames,
         as outlined by the BIDS spec.

     --long [SESSION]
         If it's a longitudinal study, specify the session label

     --acq [ACQ LABEL]
         If multiple acquisitions, provide the label. For example, the TBI study
         acquired 2 DTI scans; the acq label for the TBI study would be "iso":
            sub-<subLabel>_ses-<sessLabel>_acq-iso_dwi.nii.gz

     --params [FILE]
         A text file that will serve as the 'acqp' argument to 'eddy'

     --index [FILE]
         A text file that will serve as the 'index' argument to 'eddy'

     --mp [MPORDER]
         An integer value for the temporal order of movement. By default, it
         will choose "# slices / 4" (the recommended maximum by Jesper)

     --slspec [FILE]
         A text file that will serve as the 'slspec' argument to 'eddy'

 EXAMPLES:
     $(basename $0) -s SP7180 --long 01 --acq iso --mp 6 --slspec my_slspec.txt

!
}

# Argument checking
#-------------------------------------------------------------------------------
[[ $# == 0 ]] && usage && exit

TEMP=$(getopt -o hs: --long help,subject:,long:,acq:,params:,index:,mp:,slspec: -- "$@")
[[ $? -ne 0 ]] && usage && exit 1
eval set -- "${TEMP}"

long=0
sess=''
acq=''
mp=0
while true; do
    case "$1" in
        -h|--help)      usage && exit ;;
        -s|--subject)   subj="$2"; shift ;;
        --long)         long=1; sess="$2"; shift ;;
        --acq)          acq="$2"; shift ;;
        --params)       params="$2"; shift ;;
        --index)        index="$2"; shift ;;
        --mp)           mp="$2"; shift ;;
        --slspec)       slspec="$2"; shift ;;
        *)              break ;;
    esac
    shift
done

source $(dirname "${BASH_SOURCE[0]}")/dti_vars.sh
cd ${projdir}/${resdir}

#-------------------------------------------------------------------------------
# Setup eddy
#-------------------------------------------------------------------------------
mkdir -p eddy
if [[ ! -f ${projdir}/${params} ]]; then
    printf "0 1 0 0.0646" > eddy/acqparams.txt
else
    ln ${projdir}/${params} eddy/acqparams.txt
fi

if [[ ! -f ${projdir}/${index} ]]; then
    nvols=$(${FSLDIR}/bin/fslnvols dwi_orig)
    indx=""
    for ((i=1; i<=${nvols}; i+=1)); do indx="$indx 1"; done
    echo $indx > eddy/index.txt
else
    ln ${projdir}/${index} eddy/index.txt
fi

# For slice-to-volume correction
nslices=$(${FSLDIR}/bin/fslval dwi_orig dim3)
if [[ ${mp} -eq 0 ]]; then
    mp=$(expr ${nslices} / 4)   # Max. recommended by Jesper
fi
echo "MP is: $mp"
if [[ ! -f ${projdir}/${slspec} ]]; then
    manuf=$(grep Manufacturer\" ${projdir}/${rawdir}/${target}.json)
    reptime=$(grep Repetition ${projdir}/${rawdir}/${target}.json | cut -d: -f2 | sed 's/,//')
    case ${manuf} in
        *Philips*|*GE*)
            # For the TBI stress study, DWI is acquired sequentially ("single package default")
            timediff=$(echo "${reptime} / ${nslices}" | bc -l)
            for ((i=0; i<${nslices}; i++)); do
                echo "$i * ${timediff}" | bc -l >> eddy/slspec.txt
            done
            ;;
        *)
            # Assume interleaved 1, 3, 5, ..., 2, 4, 6, ...
            Rscript --vanilla -e "source('${scriptdir}/../R/slice_times.R'); slice_times(${nslices}, ${reptime})"
            mv slspec.txt eddy
            ;;
    esac
else
    ln ${projdir}/${slspec} eddy/slspec.txt
fi

#-------------------------------------------------------------------------------
# Run eddy
#-------------------------------------------------------------------------------
export SGE_ROOT=''
echo -e '\n Running "eddy"!'
${FSLDIR}/bin/eddy_cuda \
    --imain=dwi_orig \
    --mask=nodif_brain_mask \
    --index=eddy/index.txt \
    --acqp=eddy/acqparams.txt \
    --bvecs=bvecs.norot \
    --bvals=bvals \
    --repol \
    --mporder=${mp} \
    --slspec=eddy/slspec.txt \
    --residuals \
    --cnr_maps \
    --out=eddy/dwi_eddy
ln eddy/dwi_eddy.nii.gz data.nii.gz #TODO change to outlier free?
ln eddy/dwi_eddy.eddy_rotated_bvecs bvecs

#-------------------------------------------------------------------------------
# Run dtifit
#-------------------------------------------------------------------------------
mkdir -p dtifit
${FSLDIR}/bin/dtifit -k data -m nodif_brain_mask -o dtifit/dtifit \
    -r bvecs -b bvals --sse --save_tensor
${FSLDIR}/bin/fslmaths dtifit/dtifit_L2 \
    -add dtifit/dtifit_L3 \
    -div 2 \
    dtifit/dtifit_RD
