#!/bin/bash
#
#SBATCH -N 1                # Total number of nodes (48 cores/node; 2 threads/core)
#SBATCH -n 65               # Total number of tasks
#SBATCH -p skx-normal       # Queue name
#SBATCH -t 00:30:00         # Run time (hh:mm:ss)
#SBATCH --mail-type=end
#SBATCH --mail-user=Christopher.G.Watson@uth.tmc.edu
#------------------------------------------------------
module load launcher
export LAUNCHER_WORKDIR=${PWD}

${HOME}/code/dnl_library/bin/fsl/fsl_bedpostx.sh "$@"

#----------------
# Job Submission
#----------------
cd $LAUNCHER_WORKDIR/
echo " WORKING DIR:   $LAUNCHER_WORKDIR/"
$TACC_LAUNCHER_DIR/paramrun

echo " Parameteric Job Complete"

${HOME}/code/dnl_library/bin/fsl/fsl_bedpostx_postproc.sh "$@"
