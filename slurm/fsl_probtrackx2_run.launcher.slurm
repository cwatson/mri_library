#!/bin/bash
#
#SBATCH -J ptx_run          # Job name
#SBATCH -N 1                # Total number of nodes (16 cores/node)
#SBATCH -n 16               # Total number of tasks
#SBATCH -p skx-normal           # Queue name
#SBATCH -o ${WORK}/stress_study/logs/ptx_run        # Name of stdout output file (%j expands to jobid)
#SBATCH -t 04:00:00         # Run time (hh:mm:ss)
#SBATCH --mail-type=end
#SBATCH --mail-user=Christopher.G.Watson@uth.tmc.edu
#------------------------------------------------------
module load launcher
export LAUNCHER_JOB_FILE=${WORK}/stress_study/logs/ptx_run_${1}.paramlist
export LAUNCHER_WORKDIR=${PWD}

base_dir=${WORK}/stress_study/dti
bedpost_dir=${base_dir}/${1}/dti2.bedpostX
seed_dir=${base_dir}/${1}/dti2.probtrackX2/seeds/dk.scgm
seed_file=${seed_dir}/seeds_sorted.txt

[[ -f ${LAUNCHER_JOB_FILE} ]] && rm ${LAUNCHER_JOB_FILE}
while read line; do
    echo "probtrackx2 -x ${line} -s ${bedpost_dir}/merged -m ${bedpost_dir}/nodif_brain_mask --omatrix1 --os2t --otargetpaths --s2tastext -P 5000 --forcedir --opd --pd --dir=${base_dir}/${1}/dti2.probtrackX2/results/dk.scgm/$(basename ${line} .nii.gz) --targetmasks=${seed_file} --avoid=${seed_dir}/ventricles.nii.gz" >> ${LAUNCHER_JOB_FILE}
done < ${seed_file}
#--------------------------------------------------------

#----------------
# Job Submission
#----------------
cd $LAUNCHER_WORKDIR/
echo " WORKING DIR:   $LAUNCHER_WORKDIR/"
$TACC_LAUNCHER_DIR/paramrun

echo " Parameteric Job Complete"
