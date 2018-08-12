#!/bin/bash
#
#SBATCH -N 1                # Total number of nodes (16 cores/node)
#SBATCH -p skx-normal       # Queue name
#SBATCH -t 00:30:00         # Run time (hh:mm:ss)
#SBATCH --mail-type=end
#SBATCH --mail-user=Christopher.G.Watson@uth.tmc.edu
#------------------------------------------------------
module load launcher
export LAUNCHER_JOB_FILE=${WORK}/stress_study/logs/stampede2/qa_preproc.paramlist
export LAUNCHER_WORKDIR=${PWD}

for subj in "$@"; do
    sub=${subj/tractography\/sub-/}
    echo "${HOME}/code/dnl_library/bin/fsl/fsl_qa_dti_preproc.sh -s ${sub} --bids --long 01 --acq iso" >> ${LAUNCHER_JOB_FILE}
done

#----------------
# Job Submission
#----------------
cd $LAUNCHER_WORKDIR/
echo " WORKING DIR:   $LAUNCHER_WORKDIR/"
$TACC_LAUNCHER_DIR/paramrun

echo " Parameteric Job Complete"
