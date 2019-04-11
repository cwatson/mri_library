#! /bin/bash
# Chris Watson, 2019-04-11
set -a
source $(dirname "${BASH_SOURCE[0]}")/globals.sh

usage() {
    cat << !

 Move a subject's data to the ${myblue}unusable$(tput sgr0) directory.

 ${myyellow}USAGE:${mygreen}
    $(basename $0) -s|--subject SUBJECT -m|--modality MODALITY
        [--long SESSION] [--acq LABEL]

 ${myyellow}OPTIONS:
     ${mymagenta}-h, --help$(tput sgr0)
         Show this message

     ${mymagenta}-s, --subject [SUBJECT]$(tput sgr0)
         Subject ID. This will be the "label" in the directories and filenames,
         as outlined by the BIDS spec.

     ${mymagenta}-m, --modality [MODALITY]$(tput sgr0)
         The imaging modality. If ${myblue}T1w$(tput sgr0) is selected, then all subject data will be
         moved to the ${myblue}unusable$(tput sgr0) directory. By default, the modality is assumed to
         be ${myblue}DWI$(tput sgr0).

     ${mymagenta}--long [SESSION]$(tput sgr0)
         If it's a longitudinal study, specify the session label

     ${mymagenta}--acq [ACQ LABEL]$(tput sgr0)
         If multiple acquisitions, provide the label. For example, the TBI study
         acquired 2 DTI scans; the acq label for the TBI study would be "iso":
            ${mygreen}sub-<subLabel>_ses-<sessLabel>_acq-iso_dwi.nii.gz

 ${myyellow}EXAMPLES:${mygreen}
     $(basename $0) -s SP8223 --long 02 -acq iso

!
}

# Argument checking
#-------------------------------------------------------------------------------
[[ $# -eq 0 ]] && usage && exit

TEMP=$(getopt -o hs:m: --long help,subject:,modality:,long:,acq: -- "$@")
[[ $? -ne 0 ]] && usage && exit 64
eval set -- "${TEMP}"

long=0
sess=''
acq=''
while true; do
    case "$1" in
        -h|--help)      usage && exit ;;
        -s|--subject)   subj="$2"; shift ;;
        -m|--modality)  modality="$2"; shift ;;
        --long)         long=1; sess="$2"; shift ;;
        --acq)          acq="$2"; shift ;;
        *)              break ;;
    esac
    shift
done

source $(dirname "${BASH_SOURCE[0]}")/setup_vars.sh

# Create and move directories
#-------------------------------------------------------------------------------
mkdir -p unusable
if [[ ${mod_dir} == 'anat' ]]; then
    source_dest=unusable/sourcedata
    source_orig=sourcedata/sub-${subj}
    if [[ ${long} -eq 1 ]]; then
        source_dest=${source_dest}/sub-${subj}
        source_orig=${source_orig}/ses-${sess}
    fi
    raw_dest=${source_dest/sourcedata/rawdata}
    raw_orig=${source_orig/sourcedata/rawdata}

    mkdir -p ${source_dest} ${raw_dest}
    mv ${source_orig} ${source_dest}
    mv ${raw_orig} ${raw_dest}

    # Remove the subject directory if it is now empty
    if [[ ${long} -eq 1 ]]; then
        if [[ -z "$(ls -A sourcedata/sub-${subj})" ]]; then
            rmdir {sourcedata,rawdata}/sub-${subj}
        fi
    fi

    tract_orig=${source_orig/sourcedata/tractography}
else
    source_dest=unusable/sourcedata/sub-${subj}
    if [[ ${long} -eq 1 ]]; then
        source_dest=${source_dest}/ses-${sess}
    fi
    raw_dest=${source_dest/sourcedata/rawdata}
    source_orig=${source_dest#unusable/}/${mod_dir}
    raw_orig=${source_orig/sourcedata/rawdata}

    mkdir -p ${source_dest} ${raw_dest}
    mv ${source_orig} ${source_dest}
    mv ${raw_orig} ${raw_dest}

    # If the subject or session directory is empty, remove them
    if [[ -z "$(ls -A ${source_orig%*${mod_dir}})" ]]; then
        rmdir ${source_orig%*${mod_dir}}
    fi
    if [[ -z "$(ls -A ${raw_orig%*${mod_dir}})" ]]; then
        rmdir ${raw_orig%*${mod_dir}}
    fi
    if [[ -z "$(ls -A sourcedata/sub-${subj})" ]]; then
        rmdir {sourcedata,rawdata}/sub-${subj}
    fi

    if [[ ${mod_dir} == 'dwi' ]]; then
        tract_orig=${source_orig/sourcedata/tractography}
        tract_orig=${tract_orig%/dwi}
    fi
fi

# Check if there are tractography results and move them to unusable, too
if [[ -n ${tract_orig} ]]; then
    tract_dest=${source_dest/sourcedata/tractography}
    if [[ ${long} -eq 1 ]]; then
        tract_dest=${tract_dest%*/ses*}
    fi
    if [[ -d ${tract_orig} ]]; then
        mkdir -p ${tract_dest}
        mv ${tract_orig} ${tract_dest}

        # Check if the whole subject directory is empty
        tract=tractography/sub-${subj}
        if [[ -d ${tract} ]] && [[ -z "$(ls -A ${tract})" ]]; then
            rmdir ${tract}
        fi
    fi
fi
