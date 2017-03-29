#! /bin/bash
#
# Run a different instance of probtrackx2 for all seeds
#_______________________________________________________________________________
# updated 2017-03-28
# Chris Watson, 2016-11-02

usage() {
    cat << !

    usage: $(basename $0) [options]

    This script will run "probtrackx2" w/ a separate process for each seed ROI.

    OPTIONS:
        -h          Show this message
        -a          Atlas (default: 'dk.scgm')
        -s          Subject name/ID
        -P          Number of samples (default: 5000)

    EXAMPLE:
        $(basename $0) -a dk.scgm -s SP7104_time1 -P 1000

!
}

# Argument checking
#-------------------------------------------------------------------------------
[[ $# == 0 ]] && usage && exit

while getopts ":ha:s:P:" OPTION; do
    case $OPTION in
        a) atlas="$OPTARG" ;;
        s) subj="$OPTARG" ;;
        P) nSamples="$OPTARG" ;;
        *) usage && exit ;;
    esac
done

[[ -z ${nSamples} ]] && nSamples=5000
[[ -z ${atlas} ]] && atlas=dk.scgm
bpx_dir=${subj}/dti2.bedpostX
seed_dir=${subj}.probtrackX2/seeds/${atlas}
seed_file=${seed_dir}/seeds_sorted.txt
res_dir=${subj}/dti2.probtrackX2/results_alt/${atlas}

[[ ! -e "timing_ptx.csv" ]] && touch timing_ptx.csv
start=$(date +%s)

while read line; do
    sem --bar -j+0 probtrackx2 \
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

end=$(date +%s)
runtime=$((end-start))
totalsize=$(awk '{sum+=$1} END {print sum}' ${seed_dir}/sizes.txt)
echo "${nSamples},${runtime},${totalsize}" >> ~/timing_ptx.csv
