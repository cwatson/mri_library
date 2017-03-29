#! /bin/bash
#SBATCH -N 1                # Total number of nodes (16 cores/node)
#SBATCH -n 16               # Total number of tasks
#SBATCH -p gpu              # Queue name
#SBATCH -t 00:15:00         # Run time (hh:mm:ss)
#SBATCH --mail-type=end
#SBATCH --mail-user=Christopher.G.Watson@uth.tmc.edu
module load cuda/6.5

${HOME}/code/bin/fsl_dti_preproc.sh -s ${1} -f ${2}
