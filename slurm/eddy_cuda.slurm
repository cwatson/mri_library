#! /bin/bash
# Script that runs FSL6's 'eddy_cuda' on Lonestar5 using a Singularity
# container. This requires prepending the 'eddy_cuda' command with the variable
# $FSL6_CUDA_EXEC (which I do in 'dti_eddy.sh').
#SBATCH -N 1            # Total number of nodes (16 cores/node)
#SBATCH -n 1            # Total number of tasks
#SBATCH -p gpu          # Queue name
#SBATCH -t 00:20:00     # Run time (hh:mm:ss)
#SBATCH --mail-type=end
#SBATCH --mail-user=Christopher.G.Watson@uth.tmc.edu

set -a
module load tacc-singularity
module load Rstats
export scriptdir=$(dirname $(type -p dti_eddy.sh))
${scriptdir}/dti_eddy.sh "$@"
