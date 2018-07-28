#! /bin/bash
#SBATCH -N 1                # Total number of nodes (16 cores/node)
#SBATCH -n 33               # Total number of tasks
#SBATCH -p skx-normal       # Queue name
#SBATCH -t 00:10:00         # Run time (hh:mm:ss)
#SBATCH --mail-type=end
#SBATCH --mail-user=Christopher.G.Watson@uth.tmc.edu

#module load cuda/6.5
export OMP_NUM_THREADS=33

${HOME}/code/dnl_library/bin/fsl/fsl_dti_preproc.sh "$@"
