#! /bin/bash
# Chris Watson, 2017-02-28
set -a
source $(dirname "${BASH_SOURCE[0]}")/globals.sh

usage() {
    cat << !

 Extract DICOM files and convert to NIfTI. Run brain extraction, and then create
 some screenshots for QC purposes. Finally, log system and software version
 information into a ${myblue}.json$(tput sgr0) file.

 ${myyellow}USAGE:${mygreen}
    $(basename $0) -s|--subject SUBJECT [-t|--threshold THRESH]
        [--rerun] [--long SESSION] [--acq LABEL] [--tgz FILE]

 ${myyellow}OPTIONS:
     ${mymagenta}-h, --help$(tput sgr0)
         Show this message

     ${mymagenta}-s, --subject [SUBJECT]$(tput sgr0)
         Subject ID. This will be the "label" in the directories and filenames,
         as outlined by the BIDS spec.

     ${mymagenta}-t, --threshold [THRESH]$(tput sgr0)
         Intensity threshold for ${myblue}bet$(tput sgr0) ${mymagenta}[default: 0.5]

     ${mymagenta}--rerun$(tput sgr0)
         Include if you want to re-run ${myblue}bet$(tput sgr0); will skip DICOM extraction and
         conversion to NIfTI

     ${mymagenta}--long [SESSION]$(tput sgr0)
         If it's a longitudinal study, specify the session label

     ${mymagenta}--acq [ACQ LABEL]$(tput sgr0)
         If multiple acquisitions, provide the label. For example, the TBI study
         acquired 2 DTI scans; the acq label for the TBI study would be "iso":
            ${mygreen}sub-<subLabel>_ses-<sessLabel>_acq-iso_dwi.nii.gz

     ${mymagenta}--tgz [TGZ FILE]$(tput sgr0)
         You can pass a specific ${myblue}.tar.gz$(tput sgr0) file containing the DICOM's if you have
         not already set-up and placed it in the ${myblue}sourcedata$(tput sgr0) directory tree. This
         will rename it to follow the BIDS spec.

 ${myyellow}EXAMPLES:${mygreen}
     $(basename $0) -s SP7104_time1 -t 0.4
     $(basename $0) -s SP7180_time1 --rerun
     $(basename $0) -s SP7180 --long 01 --acq iso

!
}

# Argument checking
#-------------------------------------------------------------------------------
[[ $# == 0 ]] && usage && exit

TEMP=$(getopt -o hs:t: --long help,subject:,threshold:,rerun,long:,acq:,tgz: -- "$@")
[[ $? -ne 0 ]] && usage && exit 1
eval set -- "${TEMP}"

thresh=0.5
rerun=0
long=0
sess=''
acq=''
tgz=''
while true; do
    case "$1" in
        -h|--help)      usage && exit ;;
        -s|--subject)   subj="$2"; shift ;;
        -t|--threshold) thresh="$2"; shift ;;
        --rerun)        rerun=1 ;;
        --long)         long=1; sess="$2"; shift ;;
        --acq)          acq="$2"; shift ;;
        --tgz)          tgz="$2"; shift ;;
        *)              break ;;
    esac
    shift
done

source $(dirname "${BASH_SOURCE[0]}")/dti_vars.sh

#-------------------------------------------------------------------------------
# Extract and convert DICOMs, if necessary
#-------------------------------------------------------------------------------
if [[ ${rerun} -eq 0 ]]; then
    mkdir -p ${rawdir} ${resdir}/qc_bet
    cd ${projdir}/${srcdir}

    # Extract first file, determine Manufacturer,
    # then extract entire archive
    #-------------------------------------------------------
    if [[ ${tgz} != '' ]]; then
        if [[ -f ${tgz} ]]; then
            mv ${tgz} ${projdir}/${srcdir}/${target}_dicom.tar.gz
        else
            echo "Input file ${tgz} is invalid."
            echo "Please make sure to use the full path to the file."
            exit 9
        fi
    fi
    if [[ ! -f ${target}_dicom.tar.gz ]]; then
        echo "Could not find DICOM 'tar' archive."
        exit 10
    fi
    firstfile=$(tar tf ${target}_dicom.tar.gz | grep -v '/$' | head -1)
    tar xf ${target}_dicom.tar.gz ${firstfile} --xform='s#^.+/##x'
    manuf=$(dcmdump +P 0008,0070 $(basename ${firstfile}) | cut -d"[" -f2 | cut -d"]" -f1)
    rm $(basename ${firstfile})

    mkdir tmp
    if [[ ${manuf} == *"Philips"* ]]; then
        # Philips data I've processed has a "0000001" directory; don't remove
        tar xf ${target}_dicom.tar.gz -C tmp
    else
        tar xf ${target}_dicom.tar.gz --xform='s#^.+/##x' -C tmp
    fi

    # Convert DICOMs to NIfTI
    #-------------------------------------------------------
    dcmconv=$(type -P dcm2niix)
    ${dcmconv} -z i -b y -f ${target} -o . tmp
    rm -r tmp

    # Copy files to results directory; average the b0's
    #-------------------------------------------------------
    lowb=$(awk '{for(i=1;i<=NF;i++){if($i==0)x[i]=i}}END{for(i in x){print x[i] - 1}}' ${target}.bval)
    mv ${target}.{bvec,bval,json,nii.gz} ${projdir}/${rawdir}/
    cd ${projdir}/${resdir}
    ln ${projdir}/${rawdir}/${target}.bval bvals
    ln ${projdir}/${rawdir}/${target}.bvec bvecs.norot
    ln ${projdir}/${rawdir}/${target}.nii.gz dwi_orig.nii.gz

    ct=1
    for i in ${lowb}; do
        ${FSLDIR}/bin/fslroi dwi_orig lowb${ct} ${i} 1
        let "ct += 1"
    done
    ${FSLDIR}/bin/fslmerge -t lowb lowb[[:digit:]]*
    ${FSLDIR}/bin/fslmaths lowb -Tmean nodif
    rm lowb*

else
    cd ${projdir}/${resdir}
fi

${FSLDIR}/bin/bet nodif{,_brain} -m -R -f ${thresh}
source ${scriptdir}/dti_qc_bet.sh

# Store system and software information in JSON file
cd ${projdir}/${resdir}
log_system_info
for sw in dcmtk jo jq fsl; do
    log_sw_info ${sw}
done
jo -d. bet.f=${thresh} | jq -s add preproc.json - > tmp.json
mv tmp.json preproc.json
