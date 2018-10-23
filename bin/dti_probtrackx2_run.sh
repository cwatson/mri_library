#! /bin/bash
#
# Run a different instance of probtrackx2 for all seeds, or in network mode.
#_______________________________________________________________________________
# updated 2017-03-28
# Chris Watson, 2016-11-02
#TODO add flag to turn on/off "--pd"??? TODO

usage() {
    cat << !

    usage: $(basename $0) [options]

    This script will run "probtrackx2" w/ a separate process for each seed ROI,
    or if "--network" is included, then in network mode. The GPU version is used
    unless "--parallel" is included.

    OPTIONS:
        -h          Show this message
        -a          Atlas (default: 'dk.scgm')
        -s          Subject name/ID
        -P          Number of samples (default: 5000)
        --parallel  Include if you want to do in parallel (if not, the GPU
                    version will be called as well)
        --network   Run in network mode (overrides "--parallel")

    EXAMPLE:
        $(basename $0) -a dk.scgm -s SP7104_time1 -P 1000 --parallel
        $(basename $0) -a dkt.scgm -s cd001

!
}

# Argument checking
#-------------------------------------------------------------------------------
[[ $# == 0 ]] && usage && exit

TEMP=$(getopt -o ha:s:P: --long parallel,network -- "$@")
[[ $? -ne 0 ]] && usage && exit 1
eval set -- "${TEMP}"

run_parallel=0
run_network=0
while true; do
    case "$1" in
        -h)         usage && exit ;;
        -a)         atlas="$2"; shift ;;
        -s)         subj="$2"; shift ;;
        -P)         nSamples="$2"; shift ;;
        --parallel) run_parallel=1 ;;
        --network)  run_network=1 ;;
        * )         break ;;
    esac
    shift
done

[[ -z ${nSamples} ]] && nSamples=5000
[[ -z ${atlas} ]] && atlas=dk.scgm
bpx_dir=${subj}.bedpostX
seed_dir=${subj}.probtrackX2/seeds/${atlas}
seed_file=${seed_dir}/seeds_sorted.txt
res_dir=${subj}.probtrackX2/results/${atlas}

[[ ! -e "timing_ptx.csv" ]] && touch timing_ptx.csv
start=$(date +%s)

#-----------------------------------------------------------
# Run in parallel with regular ptx2, or not with GPU version
#-----------------------------------------------------------
if [[ ${run_parallel} -eq 1 ]]; then
    while read line; do
        sem -j+0 probtrackx2 \
            -x ${line} \
            -s ${bpx_dir}/merged \
            -m ${bpx_dir}/nodif_brain_mask \
            -P ${nSamples} \
            --omatrix1 \
            --os2t \
            --otargetpaths \
            --s2tastext \
            --forcedir \
            --opd \
            --avoid=${seed_dir}/ventricles.nii.gz \
            --dir=${res_dir}/$(basename ${line} .nii.gz) \
            --targetmasks=${seed_file}
    done < ${seed_file}
else
    if [[ ${run_network} -eq 0 ]]; then
        while read line; do
            probtrackx2_gpu \
                -x ${line} \
                -s ${bpx_dir}/merged \
                -m ${bpx_dir}/nodif_brain_mask \
                -P ${nSamples} \
                --omatrix1 \
                --os2t \
                --otargetpaths \
                --s2tastext \
                --forcedir \
                --opd \
                --avoid=${seed_dir}/ventricles.nii.gz \
                --dir=${res_dir}/$(basename ${line} .nii.gz) \
                --targetmasks=${seed_file}
        done < ${seed_file}
    else
        #TODO should I include "--omatrix1" and others?
        probtrackx2_gpu \
            --network \
            -x ${seed_dir}/seeds.txt \
            -s ${bpx_dir}/merged \
            -m ${bpx_dir}/nodif_brain_mask \
            -P ${nSamples} \
            --forcedir \
            --opd \
            --avoid=${seed_dir}/ventricles.nii.gz \
            --dir=${res_dir}/network.gpu/
    fi
fi

end=$(date +%s)
runtime=$((end-start))
nVoxels=$(awk '{sum+=$1} END {print sum}' ${seed_dir}/sizes.txt)
#TODO figure out what the "0" is; should be ${run_parallel}?
#TODO add ${run_network} now
echo "${subj},${runtime},${nSamples},0,${nVoxels}" >> timing_ptx.csv
