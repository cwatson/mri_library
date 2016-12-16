#! /bin/bash
#
# Run a different instance of probtrackx2 for all seeds
#_______________________________________________________________________________
# Chris Watson, 2016-11-02

usage()
{
    cat << !

    usage: $(basename $0) [options]

    This script will run "probtrackx2" w/ a separate process for each seed ROI.

    OPTIONS:
        -h          Show this message
        -a          Atlas (default: 'dk.scgm')
        -s          Subject name/ID
        -P          Number of samples (default: 5000)

    EXAMPLE:
        $(basename $0)
            -a dk.scgm
            -s SP7104_time1
            -P 1000

!
}

while :
do
    case $1 in
        -h)
            usage
            exit 99
            ;;

        -a)
            if [[ -n "$2" ]]; then
                atlas=$2
                shift
            else
                echo -e "\nOption \"$1\" requires an argument\n"
                exit 1
            fi
            ;;

        -s)
            if [[ -n "$2" ]]; then
                subj=$2
                shift
            else
                echo -e "\nOption \"$1\" requires an argument\n"
                exit 2
            fi
            ;;

        -P)
            if [[ -n "$2" ]]; then
                nSamples=$2
                shift
            else
                echo -e "\nOption \"$1\" requires an argument\n"
                exit 3
            fi
            ;;

        *)
            break
            ;;
    esac

    shift
done

if [[ ! -d "dti" ]] || [[ ! -d "vol" ]]; then
    echo -e "Must be in base study directory!\n"
    exit 4
fi

# Argument checking
#-------------------------------------------------------------------------------
if [[ -z ${atlas} ]]; then
    atlas=dk.scgm
fi

if [[ -z ${nSamples} ]]; then
    nSamples=5000
fi


seed_file=dti/${subj}/dti2.probtrackX2/seeds/${atlas}/seeds_sorted.txt
start=$(date +%s)
for cur_seed in $(cat ${seed_file}); do
    sem --bar -j+0 probtrackx2 \
        -x ${cur_seed} \
        -s dti/${subj}/dti2.bedpostX/merged \
        -m dti/${subj}/dti2.bedpostX/nodif_brain_mask \
        --omatrix1 \
        --os2t \
        --otargetpaths \
        --s2tastext \
        -P ${nSamples} \
        --forcedir \
        --opd \
        --dir=dti/${subj}/dti2.probtrackX2/results_alt/${atlas}/$(basename ${cur_seed} .nii.gz) \
        --targetmasks=${seed_file}
done
end=$(date +%s)
runtime=$((end-start))
totalsize=$(awk '{sum+=$1} END {print sum}' dti/${subj}/dti2.probtrackX2/seeds/${atlas}/sizes.txt)
echo "${nSamples},${runtime},${totalsize}" >> ~/runtime.csv
