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
export LAUNCHER_JOB_FILE=${WORK}/stress_study/logs/stampede2/bpx/bpx.${1}.paramlist
export LAUNCHER_WORKDIR=${PWD}

# Parse option arguments
#-------------------------------------------------------------------------------
subjdir=$(realpath ${1}/dti2 | sed 's:/$:$:')
nfibres=3
fudge=1
burnin=1000
njumps=1250
sampleevery=25
model=2
gflag=0
nocuda=0
other=""

shift
while [ ! -z "$1" ]; do
  case "$1" in
      -n)       nfibres=$2; shift ;;
      -w)       fudge=$2; shift ;;
      -b)       burnin=$2; shift ;;
      -j)       njumps=$2; shift ;;
      -s)       sampleevery=$2; shift ;;
      -model)   model=$2; shift ;;
      -g)       gflag=1 ;;
      -c)       nocuda=1 ;;
      *)        other=$other" "$1 ;;
  esac
  shift
done
opts="--nf=$nfibres --fudge=$fudge --bi=$burnin --nj=$njumps --se=$sampleevery --model=$model"
defopts="--cnonlinear"
opts="$opts $defopts $other"

echo subjectdir is $subjdir
echo Making bedpostx directory structure
mkdir -p ${subjdir}.bedpostX/{diff_slices,logs/monitor,xfms}

# Preprocessing
#-------------------------------------------------------------------------------
echo Queuing preprocessing stages
export LC_ALL=C
cp ${subjdir}/{bvecs,bvals,nodif_brain.nii.gz,nodif_brain_mask.nii.gz} ${subjdir}.bedpostX
${FSLDIR}/bin/fslslice ${subjdir}/data
${FSLDIR}/bin/fslslice ${subjdir}/nodif_brain_mask

# Parallel processing stage
#-------------------------------------------------------------------------------
echo Queuing parallel processing stage
nslices=$(${FSLDIR}/bin/fslval ${subjdir}/data dim3)
slice=0
while [ $slice -lt $nslices ]; do
    echo "${FSLDIR}/bin/bedpostx_single_slice.sh ${subjdir} ${slice} $opts" >> ${LAUNCHER_JOB_FILE}
    slice=$(($slice + 1))
done

#----------------
# Job Submission
#----------------
cd $LAUNCHER_WORKDIR/
echo " WORKING DIR:   $LAUNCHER_WORKDIR/"
$TACC_LAUNCHER_DIR/paramrun

echo " Parameteric Job Complete"
