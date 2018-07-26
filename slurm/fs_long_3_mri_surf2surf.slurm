#! /bin/bash
#SBATCH -J mris_surf2surf
#SBATCH -N 1                   # Total number of nodes (16 cores/node)
#SBATCH -n 1                  # Total number of tasks
#SBATCH -p development              # Queue name
#SBATCH -t 00:30:00            # Run time (hh:mm:ss)
#SBATCH --mail-type=end
#SBATCH --mail-user=Christopher.G.Watson@uth.tmc.edu
module load freesurfer
export SUBJECTS_DIR=/work/04484/cgwatson/stress_study/vol/Long_analysis/longdirs

mri_surf2surf --hemi rh --s study_average --sval rh.thickness.mgh --tval rh.thickness_sm10.mgh --fwhm-trg 10 --cortex --noreshape
