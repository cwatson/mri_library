#!/bin/bash
#
#SBATCH -J weightedMat      # Job name
#SBATCH -N 1                # Total number of nodes (16 cores/node)
#SBATCH -n 16               # Total number of tasks
#SBATCH -p skx-normal           # Queue name
#SBATCH -o ${WORK}/stress_study/logs/weightedMat_FA_0.9   # Name of stdout output file (%j expands to jobid)
#SBATCH -t 04:30:00         # Run time (hh:mm:ss)
#SBATCH --mail-type=end
#SBATCH --mail-user=Christopher.G.Watson@uth.tmc.edu
#------------------------------------------------------
thresh=0.9  #TODO make this a command line argument?
module load launcher
export LAUNCHER_JOB_FILE=${WORK}/stress_study/logs/paramlist_FA_${thresh}.wt
export LAUNCHER_WORKDIR=${PWD}

#TODO change "SP*" to "$@" but figure out how to exclude any other CLI args supplied (like "--thresh")
for subj in SP*; do
    echo "${HOME}/code/bin/fsl_probtrackx2_mean.sh -p TBI -m FA -t ${thresh} -s ${subj}" >> ${LAUNCHER_JOB_FILE}
done

#----------------
# Job Submission
#----------------
cd $LAUNCHER_WORKDIR/
echo " WORKING DIR:   $LAUNCHER_WORKDIR/"
$TACC_LAUNCHER_DIR/paramrun

echo " Parameteric Job Complete"
