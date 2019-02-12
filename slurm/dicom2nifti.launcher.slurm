#!/bin/bash
#
#SBATCH -J dicom2nifti
#SBATCH -N 1            # Total number of nodes (48 cores/node; 2 threads/core)
#SBATCH -n 65           # Total number of tasks
#SBATCH -p skx-normal   # Queue name
#SBATCH -t 00:15:00     # Run time (hh:mm:ss)
#SBATCH --mail-type=end
#SBATCH --mail-user=Christopher.G.Watson@uth.tmc.edu
#------------------------------------------------------
set -a

usage() {
 echo  'USAGE:'
 echo  '   $(basename $0) [-t|--threshold THRESH] [--long SESSION] [--acq LABEL]'
 echo  '       [--tgz FILE] [-n|--dry-run] -- SUBJECT_LIST'
 echo
 echo  'The subject list *must* come after the "--" delimiter, and can be used with'
 echo  'a glob that includes the BIDS-compliant subject label; for example, if you have'
 echo  'already set-up the "sourcedata" directory with "sub-01", "sub-02", etc. See the'
 echo  'example below.'
 echo
 echo  'If you would like to check the launcher "paramlist" file without submitting the'
 echo  'launcher job, use the "-n|--dry-run" option to create this file.'
 echo
 echo  'EXAMPLE:'
 echo  '   $(basename $0) --long 01 --acq iso -- sourcedata/sub-SP7*'
 echo  '       Will match all subjects starting "SP7xxx"'
}

module load launcher
export LAUNCHER_PLUGIN_DIR=${LAUNCHER_DIR}/plugins
export LAUNCHER_RMI=SLURM
export LAUNCHER_WORKDIR=${PWD}
export LAUNCHER_JOB_FILE=${WORK}/stress_study/logs/stampede2/dicom2nifti.paramlist
[[ -f ${LAUNCHER_JOB_FILE} ]] && rm ${LAUNCHER_JOB_FILE}

# Argument checking
#-------------------------------------------------------------------------------
TEMP=$(getopt -o ht:n --long help,threshold:,long:,acq:,tgz:,dry-run -- "$@")
[[ $? -ne 0 ]] && usage && exit
eval set -- "${TEMP}"

thresh=0.5
rerun=0
long=0
sess=''
acq=''
tgz=''
dryrun=0
while true; do
    case "$1" in
        -h|--help)      usage && exit ;;
        -t|--threshold) thresh="$2"; shift 2 ;;
        --long)         long=1; sess="$2"; shift 2 ;;
        --acq)          acq="$2"; shift 2 ;;
        --tgz)          tgz="$2"; shift 2 ;;
        -n|--dry-run)   dryrun=1; shift ;;
        --)             shift; break ;;
        *)              break ;;
    esac
done

for subj in "$@"; do
    sub=${subj##*sub-}
    if [[ -z ${tgz} ]]; then
        echo "${HOME}/code/mri_library/bin/dti_dicom2nifti_bet.sh -s ${sub} -t ${thresh} --long ${sess} --acq ${acq}" >> ${LAUNCHER_JOB_FILE}
    else
        echo "${HOME}/code/mri_library/bin/dti_dicom2nifti_bet.sh -s ${sub} -t ${thresh} --long ${sess} --acq ${acq} --tgz ${tgz}" >> ${LAUNCHER_JOB_FILE}
    fi
done

#----------------
# Job Submission
#----------------
if [[ ${dryrun} -eq 0 ]]; then
    cd $LAUNCHER_WORKDIR/
    echo " WORKING DIR:   $LAUNCHER_WORKDIR/"
    $LAUNCHER_DIR/paramrun

    echo " Parameteric Job Complete"
else
    echo "Param list file is in ${LAUNCHER_JOB_FILE}" && exit
fi
