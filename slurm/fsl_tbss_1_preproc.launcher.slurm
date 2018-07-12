#!/bin/bash
#
# To use, build the launcher executable and your
# serial application(s) and place them in your WORKDIR
# directory.  Then, edit the CONTROL_FILE to specify
# each executable per process.
#-------------------------------------------------------
#SBATCH -J tbss1      # Job name
#SBATCH -N 1                # Total number of nodes (16 cores/node)
#SBATCH -n 16               # Total number of tasks
#SBATCH -p development           # Queue name
#SBATCH -o ../logs/tbss_1_preproc   # Name of stdout output file (%j expands to jobid)
#SBATCH -t 00:02:00         # Run time (hh:mm:ss)
#SBATCH --mail-type=end
#SBATCH --mail-user=Christopher.G.Watson@uth.tmc.edu
#------------------------------------------------------
module load launcher
export EXECUTABLE=$TACC_LAUNCHER_DIR/init_launcher
export CONTROL_FILE=../logs/paramlist_tbss_1_preproc
export WORKDIR=.

mkdir origdata FA
for subj in $(${FSLDIR}/bin/imglob SP*); do
    echo "${HOME}/code/bin/fsl_tbss_1_preproc.sh ${subj}" >> ${CONTROL_FILE}
done

# Variable description:
#
#  EXECUTABLE     = full path to the job launcher executable
#  CONTROL_FILE   = text input file which specifies
#                   executable for each process
#                   (should be located in WORKDIR)
#  WORKDIR        = location of working directory
#--------------------------------------------------------
#--------------------------------------------------------

#----------------
# Error Checking
#----------------
if [ ! -f $EXECUTABLE ]; then
    echo "Error: unable to find launcher executable $EXECUTABLE."
    echo "Job not submitted."
    exit
fi

if [ ! -f $WORKDIR/$CONTROL_FILE ]; then
    echo "Error: unable to find input control file $CONTROL_FILE."
    echo "Job not submitted."
    exit
fi

#----------------
# Job Submission
#----------------
cd $WORKDIR/
echo " WORKING DIR:   $WORKDIR/"
$TACC_LAUNCHER_DIR/paramrun $EXECUTABLE $CONTROL_FILE

echo " Parameteric Job Complete"
