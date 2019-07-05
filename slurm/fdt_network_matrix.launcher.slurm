#!/bin/bash
#
#SBATCH -J fdtNetworkMat    # Job name
#SBATCH -N 1                # Total number of nodes (16 cores/node)
#SBATCH -n 48               # Total number of tasks
#SBATCH -p skx-normal       # Queue name
#SBATCH -o fdtNetworkMat    # Name of stdout output file (%j expands to jobid)
#SBATCH -t 00:20:00         # Run time (hh:mm:ss)
#SBATCH --mail-type=end
#SBATCH --mail-user=Christopher.G.Watson@uth.tmc.edu
#------------------------------------------------------
set -a

usage() {
 echo
 echo  'USAGE:'
 echo  "   $(basename $0) -a|--atlas ATLAS [--long SESSION]"
 echo  "       [-P NUM_SAMPLES] [--pd] [-n|--dry-run]"
 echo
 echo  'EXAMPLE:'
 echo  "   sbatch $(basename $0) -a dk.scgm --long 01"
}
module load launcher
module load Rstats
export LAUNCHER_PLUGIN_DIR=${LAUNCHER_DIR}/plugins
export LAUNCHER_RMI=SLURM
export LAUNCHER_WORKDIR=${PWD}
export LAUNCHER_JOB_FILE=fdt_network_matrix.paramlist
[[ -f ${LAUNCHER_JOB_FILE} ]] && rm ${LAUNCHER_JOB_FILE}

# Check arguments
#-------------------------------------------------------------------------------
TEMP=$(getopt -o ha:P:n --long help,atlas:,long:,pd,dry-run -- "$@")
[[ $? -ne 0 ]] && usage && exit 64
eval set -- "${TEMP}"

atlas=dk.scgm
long=0
sess=''
nSamples=5000
do_pd=0
while true; do
    case "$1" in
        -h|--help)      usage && exit ;;
        -a|--atlas)     atlas=$2; shift ;;
        --long)         long=1; sess="$2"; shift ;;
        -P)             nSamples="$2" ;;
        --pd)           do_pd=1 ;;
        -n|--dry-run)   dryrun=1 ;;
        --)             break ;;
        *)              break ;;
    esac
    shift
done

scriptdir=$(dirname $(type -p dti_dicom2nifti_bet.sh))
projdir=${PWD}

for subj in "$@"; do
    sub=${subj##*sub-}
    resdir=${projdir}/tractography/sub-${sub}
    if [[ ${long} -eq 1 ]]; then
        resdir=${resdir}/ses-${sess}
    fi
    resdir=${resdir}/dwi.probtrackX2
    seed_file=${resdir}/seeds/${atlas}/seeds_sorted.txt
    if [[ ${do_pd} -eq 1 ]]; then
        resdir=${resdir}/results_pd/${atlas}
    else
        resdir=${resdir}/results_noPd/${atlas}
    fi
    echo "R -e 'source("${scriptdir}/../R/fsl_fdt_matrix.R"); fsl_fdt_matrix("${resdir}", P=${nSamples}, "${seed_file}")'" >> ${LAUNCHER_JOB_FILE}
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
