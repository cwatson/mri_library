#!/bin/bash
#
# To use, build the launcher executable and your
# serial application(s) and place them in your WORKDIR
# directory.  Then, edit the CONTROL_FILE to specify
# each executable per process.
#-------------------------------------------------------
#SBATCH -J tbss3      # Job name
#SBATCH -N 1                # Total number of nodes (16 cores/node)
#SBATCH -n 16               # Total number of tasks
#SBATCH -p development           # Queue name
#SBATCH -o ${WORK}/stress_study/logs/tbss_3_postreg   # Name of stdout output file (%j expands to jobid)
#SBATCH -t 00:05:00         # Run time (hh:mm:ss)
#SBATCH --mail-type=end
#SBATCH --mail-user=Christopher.G.Watson@uth.tmc.edu
#------------------------------------------------------
module load launcher
export EXECUTABLE=$TACC_LAUNCHER_DIR/init_launcher
export CONTROL_FILE=${WORK}/stress_study/logs/paramlist_tbss_3_postreg
export WORKDIR=.

cd FA
rm -f all.msf
best=target
echo $best > best.msf
mkdir -p ../stats
for subj in $(${FSLDIR}/bin/imglob *_FA.nii*); do
    echo "${FSLDIR}/bin/applywarp -i ${subj} -o ${subj}_to_target -r target -w ${subj}_to_target_warp --rel" >> ${CONTROL_FILE}
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
