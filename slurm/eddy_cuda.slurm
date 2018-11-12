#! /bin/bash
#SBATCH -N 1            # Total number of nodes (16 cores/node)
#SBATCH -n 1            # Total number of tasks
#SBATCH -p gpu          # Queue name
#SBATCH -t 00:15:00     # Run time (hh:mm:ss)
#SBATCH --mail-type=end
#SBATCH --mail-user=Christopher.G.Watson@uth.tmc.edu

module load cuda/9.0
export FSLMACHTYPE=linux_64-gcc6.3
export FSLDIR=${STOCKYARD}/stampede2/apps/fsl/current
export FSLDEVDIR=${FSLDIR}
export CUDA=/opt/apps/cuda/9.0
export COMPILE_GPU=1
export FSLCONFDIR=${FSLDIR}/config

${HOME}/code/mri_library/bin/dti_eddy.sh "$@"
