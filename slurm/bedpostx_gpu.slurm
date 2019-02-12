#! /bin/bash
#SBATCH -N 1                   # Total number of nodes (16 cores/node)
#SBATCH -n 1                  # Total number of tasks
#SBATCH -p gpu              # Queue name
#SBATCH -t 00:30:00            # Run time (hh:mm:ss)
#SBATCH --mail-type=end
#SBATCH --mail-user=Christopher.G.Watson@uth.tmc.edu
#-----------------------------------------------------------
set -a

usage() {
    cat << !

 USAGE:
    $(basename $0) -s|--subject SUBJECT [--long SESSION] [-h|--help]

!
}

module load cuda/9.0
export FSLMACHTYPE=linux_64-gcc6.3
export FSLDIR=${STOCKYARD}/stampede2/apps/fsl/current
export FSLDEVDIR=${FSLDIR}
export CUDA=/opt/apps/cuda/9.0
export COMPILE_GPU=1
export FSLCONFDIR=${FSLDIR}/config

# Argument checking
#-------------------------------------------------------------------------------
TEMP=$(getopt -o hs: --long help,subject:,long: -- "$@")
[[ $? -ne 0 ]] && usage && exit
eval set -- "${TEMP}"

long=0
sess=''
while true; do
    case "$1" in
        -h|--help)      usage && exit ;;
        -s|--subject)   subj="$2"; shift ;;
        --long)         long=1; sess="$2"; shift ;;
        *)              break ;;
    esac
done
source ${HOME}/code/mri_library/bin/dti_vars.sh

${FSLDIR}/bin/bedpostx_gpu ${projdir}/${resdir}
