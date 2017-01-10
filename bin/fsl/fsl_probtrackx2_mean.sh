#! /bin/bash
#
# Calculate the mean FA/MD/etc. for all tracts after a probtrackx2 run
#_______________________________________________________________________________
# Chris Watson, 2016-10-20

usage()
{
    cat << !

    usage: $(basename $0) [options]

    OPTIONS:
        -h      Show this message
        -m      Measure (FA, MD, L1, RD)
        -s      Subject ID
        -t      Threshold (proportion of max. value)

    EXAMPLE:
        $(basename $0) -m FA -s SP7104_time1 -t 0.9

!
}

while getopts ":hm:s:t:" OPTION
do
    case $OPTION in
        h)
            usage
            exit 1
            ;;

        m)
            measure="$OPTARG"
            ;;

        s)
            subj="$OPTARG"
            ;;

        t)
            thr="$OPTARG"
            ;;

        *)
            usage
            exit 99
            ;;
    esac
done

if [ $# == 0 ]
then
    usage
    exit 2
fi

if [[ ! -d ${subj} ]]; then
    echo -e "Subject ${subj} is not valid!\n"
    exit 3
fi

cd ${subj}/dti2.probtrackX2/results/dk.scgm
for seed in *
do
    cd ${seed}
    for target in target_paths*.nii.gz
    do
        fslmaths ${target} -thrp ${thr} targmask
        if [ $(fslstats targmask -V | awk '{print $1}') -eq 0 ]
        then
            echo -n "0 " >> ../W.txt
        else
            echo -n "$(fslstats ../../../../dti2/dti_${measure} -k targmask -M) " >> ../W.txt
        fi
    done
    cd -
    echo >> W.txt
done
