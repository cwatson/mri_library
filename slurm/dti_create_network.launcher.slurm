#!/bin/bash
#
#SBATCH -J weightedMat      # Job name
#SBATCH -N 1                # Total number of nodes (16 cores/node)
#SBATCH -n 48               # Total number of tasks
#SBATCH -p skx-normal           # Queue name
#SBATCH -o weightedMat_FA_0.9   # Name of stdout output file (%j expands to jobid)
#SBATCH -t 04:30:00         # Run time (hh:mm:ss)
#SBATCH --mail-type=end
#SBATCH --mail-user=Christopher.G.Watson@uth.tmc.edu
#------------------------------------------------------
set -a

module load launcher
export LAUNCHER_PLUGIN_DIR=${LAUNCHER_DIR}/plugins
export LAUNCHER_RMI=SLURM
export LAUNCHER_WORKDIR=${PWD}

# Check arguments
#-------------------------------------------------------------------------------
TEMP=$(getopt -o ha:m:t:n --long help,atlas:,measure:,threshold:,long:,acq:,pd,dry-run -- "$@")
[[ $? -ne 0 ]] && usage && exit 64
eval set -- "${TEMP}"

atlas=dk.scgm
long=0
sess=''
acq=''
measure=FA
thresh=0.9
do_pd=0
while true; do
    case "$1" in
        -h|--help)      usage && exit ;;
        -a|--atlas)     atlas=$2; shift 2 ;;
        -m|--measure)   measure=$2; shift 2 ;;
        -t|--threshold) thresh=$2; shift 2 ;;
        --long)         long=1; sess="$2"; shift 2 ;;
        --acq)          acq="$2"; shift 2 ;;
        --pd)           do_pd=1; shift ;;
        -n|--dry-run)   dryrun=1; shift ;;
        --)             shift; break ;;
        *)              break ;;
    esac
done

export LAUNCHER_JOB_FILE=${WORK}/stress_study/logs/stampede2/paramlist_FA_${thresh}.wt
[[ -f ${LAUNCHER_JOB_FILE} ]] && rm ${LAUNCHER_JOB_FILE}

scriptdir=$(dirname $(type -p dti_dicom2nifti_bet.sh))

args=("${scriptdir}/dti_create_network.sh" -a "${atlas}" -m "${measure}" -t "${thresh}")
if [[ ${long} -eq 1 ]]; then
    args+=(--long "${sess}")
fi
if [[ -n ${acq} ]]; then
    args+=(--acq "${acq}")
fi
if [[ ${do_pd} -eq 1 ]]; then
    args+=(--pd)
fi
for subj in "$@"; do
    sub=${subj##*sub-}
    echo "${args[@]} -s ${sub}" >> ${LAUNCHER_JOB_FILE}
done

#----------------
# Job Submission
#----------------
if [[ ${dryrun} -eq 0 ]]; then
    cd $LAUNCHER_WORKDIR/
    echo " WORKING DIR:   $LAUNCHER_WORKDIR/"
    $TACC_LAUNCHER_DIR/paramrun

    echo " Parameteric Job Complete"
else
    echo "Param list file is in ${LAUNCHER_JOB_FILE}" && exit
fi
