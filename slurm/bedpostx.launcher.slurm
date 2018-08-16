#!/bin/bash
#
#SBATCH -N 1                # Total number of nodes (48 cores/node; 2 threads/core)
#SBATCH -n 65               # Total number of tasks
#SBATCH -p skx-normal       # Queue name
#SBATCH -t 00:25:00         # Run time (hh:mm:ss)
#SBATCH --mail-type=end
#SBATCH --mail-user=Christopher.G.Watson@uth.tmc.edu
#------------------------------------------------------
module load launcher
export LAUNCHER_WORKDIR=${PWD}

export scriptdir=$(dirname $(which fsl_bedpostx.sh))
source ${scriptdir}/fsl_bedpostx.sh "$@"
export LAUNCHER_JOB_FILE=${bpxdir}/commands.txt

#----------------
# Job Submission
#----------------
cd $LAUNCHER_WORKDIR/
echo " WORKING DIR:   $LAUNCHER_WORKDIR/"
$TACC_LAUNCHER_DIR/paramrun

echo " Parameteric Job Complete"
