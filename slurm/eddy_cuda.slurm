#! /bin/bash
# Script that runs FSL6's 'eddy_cuda' on Lonestar5 using a Singularity
# container. This requires prepending the 'eddy_cuda' command with the variable
# $FSL6_CUDA_EXEC
#SBATCH -N 1            # Total number of nodes (16 cores/node)
#SBATCH -n 1            # Total number of tasks
#SBATCH -p gpu          # Queue name
#SBATCH -t 00:30:00     # Run time (hh:mm:ss)
#SBATCH --mail-type=end
#SBATCH --mail-user=Christopher.G.Watson@uth.tmc.edu

set -a

module load tacc-singularity
#module load cuda/9.0
#export FSLMACHTYPE=linux_64-gcc6.3
#export FSLDIR=${STOCKYARD}/stampede2/apps/fsl/current
#export FSLDEVDIR=${FSLDIR}
#export CUDA=/opt/apps/cuda/9.0
#export COMPILE_GPU=1
#export FSLCONFDIR=${FSLDIR}/config

${HOME}/code/mri_library/bin/dti_eddy.sh "$@"
