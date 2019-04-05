#! /bin/bash
#SBATCH -N 1                   # Total number of nodes (16 cores/node)
#SBATCH -n 1                  # Total number of tasks
#SBATCH -p gpu              # Queue name
#SBATCH -t 00:10:00            # Run time (hh:mm:ss)
#SBATCH --mail-type=end
#SBATCH --mail-user=Christopher.G.Watson@uth.tmc.edu
#-----------------------------------------------------------
set -a

usage() {
 echo "USAGE:"
 echo "    $(basename $0) -s|--subject SUBJECT [--long SESSION] [--acq LABEL]"
}

module load tacc-singularity
module load cuda/9.0

# Argument checking
#-------------------------------------------------------------------------------
TEMP=$(getopt -o hs: --long help,subject:,long:,acq: -- "$@")
[[ $? -ne 0 ]] && usage && exit 64
eval set -- "${TEMP}"

long=0
sess=''
acq=''
while true; do
    case "$1" in
        -h|--help)      usage && exit ;;
        -s|--subject)   subj="$2"; shift ;;
        --long)         long=1; sess="$2"; shift ;;
        --acq)          acq="$2"; shift ;;
        *)              break ;;
    esac
    shift
done

export scriptdir=$(dirname $(type -p setup_vars.sh))
source ${scriptdir}/setup_vars.sh

# 'singularity exec --nv /work/04484/cgwatson/singularity_cache/fsl-6.0.0-cuda-updated.simg'
${FSL6_CUDA_UPDATED_EXEC} bedpostx_gpu ${projdir}/${resdir}
