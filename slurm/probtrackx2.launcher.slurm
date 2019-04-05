#!/bin/bash
#
#SBATCH -J ptx_run          # Job name
#SBATCH -N 1                # Total number of nodes (16 cores/node)
#SBATCH -n 48               # Total number of tasks
#SBATCH -p skx-normal           # Queue name
#SBATCH -o ${WORK}/stress_study/logs/ptx_run        # Name of stdout output file (%j expands to jobid)
#SBATCH -t 04:00:00         # Run time (hh:mm:ss)
#SBATCH --mail-type=end
#SBATCH --mail-user=Christopher.G.Watson@uth.tmc.edu
#------------------------------------------------------
set -a

usage() {
 echo
 echo  'USAGE:'
 echo  "   $(basename $0) -a|--atlas ATLAS -s|--subject SUBJECT"
 echo  "       [--long SESSION] [--acq LABEL] [-P NUM_SAMPLES] [-n|--dry-run]"
 echo
 echo  'EXAMPLE:'
 echo  "   sbatch $(basename $0) -s SP7102 --long 01 --acq iso"
}

# Argument checking
#-------------------------------------------------------------------------------
TEMP=$(getopt -o ha:s:P:n --long help,atlas:,subject:,long:,acq:,pd,dry-run -- "$@")
[[ $? -ne 0 ]] && usage && exit
eval set -- "${TEMP}"

long=0
sess=''
acq=''
numSamples=5000
do_pd=0
while true; do
    case "$1" in
        -h|--help)      usage && exit ;;
        -a|--atlas)     atlas="$2"; shift ;;
        -s|--subject)   subj="$2"; shift ;;
        --long)         long=1; sess="$2"; shift ;;
        --acq)          acq="$2"; shift ;;
        -P)             nSamples="$2"; shift ;;
        --pd)           do_pd=1 ;;
        -n|--dry-run)   dryrun=1 ;;
        *)              break ;;
    esac
    shift
done

module load launcher
export LAUNCHER_WORKDIR=${PWD}
export LAUNCHER_JOB_FILE=${WORK}/stress_study/logs/ptx_run_${subj}.paramlist
[[ -f ${LAUNCHER_JOB_FILE} ]] && rm ${LAUNCHER_JOB_FILE}

projdir=${PWD}
resdir=${projdir}/tractography/sub-${subj}
if [[ ${long} -eq 1 ]]; then
    resdir=${resdir}/ses-${sess}
fi
resdir=${resdir}/dwi
bedpost_dir=${resdir}.bedpostX
seed_dir=${resdir}.probtrackX2/seeds/${atlas}
seed_file=${seed_dir}/seeds_sorted.txt
outdir=${resdir}.probtrackX2/results/${atlas}

args=(-s "${bedpost_dir}/merged" -m "${bedpost_dir}/nodif_brain_mask" --omatrix1)
args+=(--os2t --otargetpaths --s2tastext -P "${nSamples}")
args+=(--forcedir --opd "--avoid=${seed_dir}/ventricles.nii.gz")
args+=("--targetmasks=${seed_file}")
if [[ ${do_pd} -eq 1 ]]; then
    args+=(--pd)
fi

while read line; do
    echo "probtrackx2 -x ${line} ${args[@]}--dir=${outdir}/$(basename ${line} .nii.gz)" >> ${LAUNCHER_JOB_FILE}
#    echo "probtrackx2 -x ${line} -s ${bedpost_dir}/merged -m ${bedpost_dir}/nodif_brain_mask --omatrix1 --os2t --otargetpaths --s2tastext -P 5000 --forcedir --opd --pd --dir=${resdir}.probtrackX2/results/dk.scgm/$(basename ${line} .nii.gz) --targetmasks=${seed_file} --avoid=${seed_dir}/ventricles.nii.gz" >> ${LAUNCHER_JOB_FILE}
done < ${seed_file}
#--------------------------------------------------------

#----------------
# Job Submission
#----------------
if [[ ${dryrun} -eq 0 ]]; then
    cd $LAUNCHER_WORKDIR/
    echo " WORKING DIR:   $LAUNCHER_WORKDIR/"
    $TACC_LAUNCHER_DIR/paramrun

    echo " Parameteric Job Complete"
else
    echo "Param list file is in ${LAUNCHER_JOB_FILE}" && exit
fi
