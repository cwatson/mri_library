#! /bin/bash
#SBATCH -N 1                   # Total number of nodes (16 cores/node)
#SBATCH -n 1                  # Total number of tasks
#SBATCH -p gpu              # Queue name
#SBATCH -t 00:30:00            # Run time (hh:mm:ss)
#SBATCH --mail-type=end
#SBATCH --mail-user=Christopher.G.Watson@uth.tmc.edu
module load cuda/6.5
export FSLMACHTYPE=linux_64-gcc4.4
export FSLDEVDIR=/work/04484/cgwatson/apps/fsl/current
export CUDA=/opt/apps/cuda/6.5
export COMPILE_GPU=1
export FSLCONFDIR=/work/04484/cgwatson/apps/fsl/current/config

${WORK}/apps/fsl/current/bin/bedpostx_gpu ${1}/dti2
