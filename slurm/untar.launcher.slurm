#!/bin/bash
#
#SBATCH -J untar_all        # Job name
#SBATCH -N 1                # Total number of nodes (16 cores/node)
#SBATCH -n 16               # Total number of tasks
#SBATCH -p skx-normal      # Queue name
#SBATCH -o /work/04484/cgwatson/stress_study/logs/untar_all   # Name of stdout output file (%j expands to jobid)
#SBATCH -t 00:05:00         # Run time (hh:mm:ss)
#SBATCH --mail-type=end
#SBATCH --mail-user=Christopher.G.Watson@uth.tmc.edu
#------------------------------------------------------
module load launcher
export LAUNCHER_JOB_FILE=paramlist_untar_all
export LAUNCHER_WORKDIR=${PWD}

for f in *.tar.gz; do
    echo "tar xf ${f}" >> ${LAUNCHER_JOB_FILE}
done

#----------------
# Job Submission
#----------------
cd $LAUNCHER_WORKDIR/
echo " WORKING DIR:   $LAUNCHER_WORKDIR/"
$TACC_LAUNCHER_DIR/paramrun

echo " Parameteric Job Complete"
