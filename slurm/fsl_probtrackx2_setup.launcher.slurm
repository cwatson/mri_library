#!/bin/bash
#
#SBATCH -J ptx_setup        # Job name
#SBATCH -N 1                # Total number of nodes (16 cores/node)
#SBATCH -n 16               # Total number of tasks
#SBATCH -p skx-normal           # Queue name
#SBATCH -o ptx_setup        # Name of stdout output file (%j expands to jobid)
#SBATCH -t 01:30:00         # Run time (hh:mm:ss)
#SBATCH --mail-type=end
#SBATCH --mail-user=Christopher.G.Watson@uth.tmc.edu
#------------------------------------------------------
module load freesurfer
module load launcher
export LAUNCHER_JOB_FILE=${WORK}/stress_study/logs/ptx_setup.paramlist
export LAUNCHER_WORKDIR=${PWD}

for subj in "$@"; do
    echo "${HOME}/code/bin/fsl_probtrackx2_setup_CLI.sh -p TBI -a dk.scgm -s ${subj}" >> ${LAUNCHER_JOB_FILE}
done

#----------------
# Job Submission
#----------------
cd $LAUNCHER_WORKDIR/
echo " WORKING DIR:   $LAUNCHER_WORKDIR/"
$TACC_LAUNCHER_DIR/paramrun

echo " Parameteric Job Complete"
