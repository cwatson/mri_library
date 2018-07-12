#! /bin/bash
#
# Calculate the mean FA/MD/etc. for all tracts after a probtrackx2 run
#_______________________________________________________________________________
# Chris Watson, 2016-10-20

usage() {
    cat << !

    usage: $(basename $0) [options]

    OPTIONS:
        -h      Show this message
        -p      Project (CCFA, TBI)
        -m      Measure (FA, MD, L1, RD)
        -s      Subject ID
        -t      Threshold (proportion of max. value; default: 0.9)

    EXAMPLE:
        $(basename $0) -p TBI -m FA -s SP7104_time1 -t 0.9
        $(basename $0) -p ccfa -m FA -s cd001 -t 0.9

!
exit
}

while getopts ":hp:m:s:t:" OPTION; do
    case $OPTION in
        p) proj="$OPTARG" ;;
        m) measure="$OPTARG" ;;
        s) subj="$OPTARG" ;;
        t) thr="$OPTARG" ;;
        *) usage ;;
    esac
done

[[ $# == 0 ]] && usage
[[ ! -d ${subj} ]] && echo -e "Subject ${subj} is not valid!\n" && exit 3
[[ -z ${thr} ]] && thr=0.9
case ${proj} in
    tbi|TBI)
        cd ${subj}/dti2.probtrackX2/results/dk.scgm
        measure_im=../../../../dti2/dtifit/dtifit_${measure}
        ;;
    ccfa|CCFA)
        cd ${subj}.probtrackX2/results/dkt.scgm
        measure_im=../../../../${subj}/dtifit/${subj}_dtifit_${measure}
        ;;
    *) echo "Invalid project!\n" && usage ;;
esac

for seed in [12]*; do
    cd ${seed}
    for target in target_paths*.nii.gz; do
        fslmaths ${target} -thrp ${thr} targmask
        if [ $(fslstats targmask -V | awk '{print $1}') -eq 0 ]; then
            echo -n "0 " >> ../W.txt
        else
            echo -n "$(fslstats ${measure_im} -k targmask -M) " >> ../W.txt
        fi
    done
    cd -
    echo >> W.txt
done
