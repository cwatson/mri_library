#!/bin/bash
#
#SBATCH -J ptx_run          # Job name
#SBATCH -N 1                # Total number of nodes (16 cores/node)
#SBATCH -n 16               # Total number of tasks
#SBATCH -p normal           # Queue name
#SBATCH -o ../logs/ptx_run        # Name of stdout output file (%j expands to jobid)
#SBATCH -t 04:00:00         # Run time (hh:mm:ss)
#SBATCH --mail-type=end
#SBATCH --mail-user=Christopher.G.Watson@uth.tmc.edu
#------------------------------------------------------
base_dir=${WORK}/stress_study/dti
bedpost_dir=${base_dir}/${1}/dti2.bedpostX
seed_dir=${base_dir}/${1}/dti2.probtrackX2/seeds/dk.scgm
seed_file=${seed_dir}/seeds_sorted.txt

[[ -f "../logs/ptx_run_${1}.paramlist" ]] && rm ../logs/ptx_run_${1}.paramlist
while read line; do
    echo "probtrackx2 -x ${line} -s ${bedpost_dir}/merged -m ${bedpost_dir}/nodif_brain_mask --omatrix1 --os2t --otargetpaths --s2tastext -P 5000 --forcedir --opd --pd --dir=${base_dir}/${1}/dti2.probtrackX2/results/dk.scgm/$(basename ${line} .nii.gz) --targetmasks=${seed_file} --avoid=${seed_dir}/ventricles.nii.gz" >> ../logs/ptx_run_${1}.paramlist
done < ${seed_file}

module load launcher
export EXECUTABLE=$TACC_LAUNCHER_DIR/init_launcher
export CONTROL_FILE=../logs/ptx_run_${1}.paramlist
export WORKDIR=.

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
