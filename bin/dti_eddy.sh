#! /bin/bash
# Chris Watson, 2017-02-28
set -a
source $(dirname "${BASH_SOURCE[0]}")/globals.sh

usage() {
    cat << !

 Setup and run ${myblue}eddy$(tput sgr0) on DTI data, and then calculate some QC metrics from
 ${myblue}eddy_quad$(tput sgr0). If you do not have ${myblue}acqparams.txt$(tput sgr0), ${myblue}index.txt$(tput sgr0), or ${myblue}slspec.txt$(tput sgr0) files,
 then generic ones will be created (with values from the FSL wiki).

 If you have files that apply to all study subjects, you can pass those in via
 function arguments; these should be located in the ${myblue}${projdir}$(tput sgr0) (where the script
 is called from).

 The ${mymagenta}--fd-cutoff$(tput sgr0) option lets you choose a cutoff for classifying outliers based
 on ${myred}frame displacement (FD)$(tput sgr0). The default is 0.5 mm.

 ${myyellow}USAGE:${mygreen}
    $(basename $0) -s|--subject SUBJECT [--long SESSION] [--acq LABEL]
        [--params FILE] [--index FILE] [--mp MPORDER] [--slspec FILE]
        [--fd-cutoff MM]

 ${myyellow}OPTIONS:
     ${mymagenta}-h, --help$(tput sgr0)
         Show this message

     ${mymagenta}-s, --subject [SUBJECT]$(tput sgr0)
         Subject ID. This will be the "label" in the directories and filenames,
         as outlined by the BIDS spec.

     ${mymagenta}--long [SESSION]$(tput sgr0)
         If it's a longitudinal study, specify the session label

     ${mymagenta}--acq [ACQ LABEL]$(tput sgr0)
         If multiple acquisitions, provide the label. For example, the TBI study
         acquired 2 DTI scans; the acq label for the TBI study would be "iso":
            ${mygreen}sub-<subLabel>_ses-<sessLabel>_acq-iso_dwi.nii.gz

     ${mymagenta}--params [FILE]$(tput sgr0)
         A text file that will serve as the ${myblue}acqp$(tput sgr0) argument to ${myblue}eddy$(tput sgr0)

     ${mymagenta}--index [FILE]$(tput sgr0)
     A text file that will serve as the ${myblue}index$(tput sgr0) argument to ${myblue}eddy$(tput sgr0)

     ${mymagenta}--mp [MPORDER]$(tput sgr0)
         An integer value for the temporal order of movement. This is the same
         as the ${myblue}mporder$(tput sgr0) argument to ${myblue}eddy$(tput sgr0). ${mymagenta}[default: "# slices / 4"]$(tput sgr0)
         (the recommended maximum by Jesper)

     ${mymagenta}--slspec [FILE]$(tput sgr0)
     A text file that will serve as the ${myblue}slspec$(tput sgr0) argument to ${myblue}eddy$(tput sgr0)

     ${mymagenta}--fd-cutoff [MM]$(tput sgr0)
     The cutoff (in mm) to use when classifying outliers based on frame
     displacement (FD). The default is 0.5 mm.

 ${myyellow}EXAMPLES:${mygreen}
     $(basename $0) -s SP7180 --long 01 --acq iso --mp 6 --slspec my_slspec.txt

!
}

# Argument checking
#-------------------------------------------------------------------------------
[[ $# == 0 ]] && usage && exit

TEMP=$(getopt -o hs: --long help,subject:,long:,acq:,params:,index:,mp:,slspec:,fd-cutoff -- "$@")
[[ $? -ne 0 ]] && usage && exit
eval set -- "${TEMP}"

long=0
sess=''
acq=''
mp=0
fd=0.5
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
        --fd-cutoff)    fd="$2"; shift ;;
        *)              break ;;
    esac
    shift
done

if [[ -z ${subj} ]]; then
    echo "Please provide a subject ID."
    exit 76
fi

source $(dirname "${BASH_SOURCE[0]}")/dti_vars.sh
cd ${projdir}/${resdir}

#-------------------------------------------------------------------------------
# Check if this is being run on Lonestar5
# i.e., using a Singularity container
#-------------------------------------------------------------------------------
if [[ ! -z ${FSL6_CUDA_EXEC} ]]; then
    nvolcommand=(${FSL6_CUDA_EXEC} fslnvols)
    valcommand=(${FSL6_CUDA_EXEC} fslval)
    eddycommand=(${FSL6_CUDA_EXEC} eddy_cuda)
    qccommand=(${FSL6_CUDA_EXEC} eddy_quad)
    dticommand=(${FSL6_CUDA_EXEC} dtifit)
    mathcommand=(${FSL6_CUDA_EXEC} fslmaths)
    statcommand=(${FSL6_CUDA_EXEC} fslstats)
else
    nvolcommand=(${FSLDIR}/bin/fslnvols)
    valcommand=(${FSLDIR}/bin/fslval)
    eddycommand=(${FSLDIR}/bin/eddy_cuda)
    qccommand=(${FSLDIR}/bin/eddy_quad)
    dticommand=(${FSLDIR}/bin/dtifit)
    mathcommand=(${FSLDIR}/bin/fslmaths)
    statcommand=(${FSLDIR}/bin/fslstats)
fi

#-------------------------------------------------------------------------------
# Setup eddy
#-------------------------------------------------------------------------------
if [[ -d eddy ]]; then
    echo "'eddy' has already been run."
    echo "Please remove directory if you wish to re-run."
    exit 77
fi
mkdir -p eddy dtifit
if [[ ! -f ${projdir}/${params} ]]; then
    printf "0 1 0 0.0646" > eddy/acqparams.txt
else
    ln ${projdir}/${params} eddy/acqparams.txt
fi

if [[ ! -f ${projdir}/${index} ]]; then
    nvols=$(${nvolcommand[@]} dwi_orig)
    indx=""
    for ((i=1; i<=${nvols}; i+=1)); do indx="$indx 1"; done
    echo $indx > eddy/index.txt
else
    ln ${projdir}/${index} eddy/index.txt
fi

# For slice-to-volume correction
nslices=$(${valcommand[@]} dwi_orig dim3)
if [[ ${mp} -eq 0 ]]; then
    mp=$(expr ${nslices} / 4)   # Max. recommended by Jesper
fi

if [[ ! -f ${projdir}/${slspec} ]]; then
    manuf=$(jq .Manufacturer ${projdir}/${rawdir}/${target}.json)
    case ${manuf} in
        *Philips*|*GE*)
            # For the TBI stress study, DWI is acquired sequentially ("single package default")
            for i in $(seq 0 $((${nslices}-1))); do
                echo $i >> eddy/slspec.txt
            done
            ;;
        *)
            # Assume interleaved 1, 3, 5, ..., 2, 4, 6, ...
            for i in $(seq 0 2 $((${nslices}-1))); do
                echo $i >> eddy/slspec.txt
            done
            for i in $(seq 1 2 $((${nslices}-1))); do
                echo $i >> eddy/slspec.txt
            done
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
${eddycommand[@]} \
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
    --rms \
    --cnr_maps \
    --out=eddy/dwi_eddy
ln eddy/dwi_eddy.nii.gz data.nii.gz #TODO change to outlier free?
ln eddy/dwi_eddy.eddy_rotated_bvecs bvecs
jo eddy=$(jo mporder=${mp} repol=true residuals=true cnr_maps=true) | \
    jq -s add preproc.json - > tmp.json
mv tmp.json preproc.json

# eddy QC
#---------------------------------------
[[ -d qc/eddy ]] && rm -r qc/eddy
${qccommand[@]} eddy/dwi_eddy -o qc/eddy \
    -idx eddy/index.txt -par eddy/acqparams.txt -m nodif_brain_mask \
    -b bvals -g bvecs -s eddy/slspec.txt
echo "${projdir}/${resdir}/qc/eddy/" >> ${projdir}/tractography/quad_folders.txt

# Get other QC measures
source ${scriptdir}/dti_qc_other.sh

#-------------------------------------------------------------------------------
# Run dtifit
#-------------------------------------------------------------------------------
${dticommand[@]} -k data -m nodif_brain_mask -o dtifit/dtifit \
    -r bvecs -b bvals --sse --save_tensor
${mathcommand[@]} dtifit/dtifit_L2 \
    -add dtifit/dtifit_L3 \
    -div 2 \
    dtifit/dtifit_RD
