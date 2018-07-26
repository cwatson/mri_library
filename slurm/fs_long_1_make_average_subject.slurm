#! /bin/bash
#SBATCH -J make_avg_subj
#SBATCH -N 1                   # Total number of nodes (16 cores/node)
#SBATCH -n 1                  # Total number of tasks
#SBATCH -p normal              # Queue name
#SBATCH -o make_avg_subj
#SBATCH -t 06:00:00            # Run time (hh:mm:ss)
#SBATCH --mail-type=end
#SBATCH --mail-user=Christopher.G.Watson@uth.tmc.edu
module load freesurfer
export SUBJECTS_DIR=/work/04484/cgwatson/stress_study/vol/Long_analysis/longdirs

make_average_subject --fsgd ${SUBJECTS_DIR}/make_average_subject.fsgd \
    --out study_average
