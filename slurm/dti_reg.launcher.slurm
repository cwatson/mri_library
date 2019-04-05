#!/bin/bash
#
#SBATCH -J dti_reg
#SBATCH -N 1            # Total number of nodes (48 cores/node; 2 threads/core)
#SBATCH -n 48           # Total number of tasks
#SBATCH -p skx-normal   # Queue name
#SBATCH -t 00:15:00     # Run time (hh:mm:ss)
#SBATCH --mail-type=end
#SBATCH --mail-user=Christopher.G.Watson@uth.tmc.edu
#------------------------------------------------------
set -a

usage() {
 echo
 echo  'USAGE:'
 echo  "   $(basename $0) -a|--atlas ATLAS [--long SESSION] [--acq LABEL]"
 echo  '       [-n|--dry-run] -- SUBJECT_LIST'
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
 echo  "   sbatch $(basename $0) --atlas dk.scgm --long 01 --acq iso --"
 echo  '       sourcedata/sub-SP7*'
 echo  '   Will match all subjects starting "SP7xxx"'
}

module load launcher
export LAUNCHER_PLUGIN_DIR=${LAUNCHER_DIR}/plugins
export LAUNCHER_RMI=SLURM
export LAUNCHER_WORKDIR=${PWD}
export LAUNCHER_JOB_FILE=${WORK}/stress_study/logs/stampede2/dti_reg.paramlist
[[ -f ${LAUNCHER_JOB_FILE} ]] && rm ${LAUNCHER_JOB_FILE}

# Argument checking
#-------------------------------------------------------------------------------
TEMP=$(getopt -o ha:n --long help,atlas:,long:,acq:,dry-run -- "$@")
[[ $? -ne 0 ]] && usage && exit
eval set -- "${TEMP}"

long=0
sess=''
acq=''
dryrun=0
while true; do
    case "$1" in
        -h|--help)      usage && exit ;;
        -a|--atlas)     atlas="$2"; shift 2 ;;
        --long)         long=1; sess="$2"; shift 2 ;;
        --acq)          acq="$2"; shift 2 ;;
        -n|--dry-run)   dryrun=1; shift ;;
        --)             shift; break ;;
        *)              break ;;
    esac
done

scriptdir=$(dirname $(type -p dti_reg_FS_to_diff.sh))
ct=0
for subj in "$@"; do
    sub=${subj##*sub-}
    echo "${scriptdir}/dti_reg_FS_to_diff.sh -a ${atlas} -s ${sub} -n ${ct} --long ${sess} --acq ${acq}" >> ${LAUNCHER_JOB_FILE}
    let "ct += 1"
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
