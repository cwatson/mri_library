#! /bin/bash
#SBATCH -J mris_preproc
#SBATCH -N 1                   # Total number of nodes (16 cores/node)
#SBATCH -n 1                  # Total number of tasks
#SBATCH -p development              # Queue name
#SBATCH -t 00:30:00            # Run time (hh:mm:ss)
#SBATCH --mail-type=end
#SBATCH --mail-user=Christopher.G.Watson@uth.tmc.edu
module load freesurfer
export SUBJECTS_DIR=/work/04484/cgwatson/stress_study/vol/Long_analysis/longdirs

mris_preproc --qdec-long ${SUBJECTS_DIR}/All_subjects_long.qdec \
    --target study_average --hemi rh --meas thickness --out rh.thickness.mgh
