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
            if [ -n "$2" ]
            then
                ATLAS=$2
                shift
            else
                echo -e "\nOption \"$1\" requires an argument\n"
                exit 2
            fi
            ;;

        -s)
            if [ -n "$2" ]
            then
                SUBJ=$2
                shift
            else
                echo -e "\nOption \"$1\" requires an argument\n"
                exit 1
            fi
            ;;

        -P)
            if [ -n "$2" ]
            then
                nSamples=$2
                shift
            else
                echo -e "\nOption \"$1\" requires an argument\n"
                exit 1
            fi
            ;;

        *)
            break
            ;;
    esac

    shift
done

# Argument checking
#-------------------------------------------------------------------------------
if [[ -z ${ATLAS} ]]
then
    ATLAS=dk.scgm
fi

if [[ -z ${nSamples} ]]
then
    nSamples=5000
fi


SEEDFILE=${SUBJ}/dti2.probtrackX2/seeds/${ATLAS}/seeds_sorted.txt
#for i in {1..10}
#do
#    for j in {1..8}
#    do
#        n=$(( $j + 8 * ( $i - 1 ) ))
start=$(date +%s)
for CUR_SEED in $(cat ${SEEDFILE})
do
#        CUR_SEED=$(sed "${n}q;d" ${SEEDFILE})
        sem --bar -j+0 probtrackx2 \
            -x ${CUR_SEED} \
            -s ${SUBJ}/dti2.bedpostX/merged \
            -m ${SUBJ}/dti2.bedpostX/nodif_brain_mask \
            --omatrix1 \
            --os2t \
            --otargetpaths \
            --s2tastext \
            -P ${nSamples} \
            --forcedir \
            --opd \
            --dir=${SUBJ}/dti2.probtrackX2/results2/${ATLAS}/$(basename ${CUR_SEED}) \
            --targetmasks=${SEEDFILE} #&
#    done
#    wait
done
end=$(date +%s)
runtime=$((end-start))
totalsize=$(awk '{sum+=$1} END {print sum}' ${SUBJ}/dti2.probtrackX2/seeds/${ATLAS}/sizes.txt)
echo "${nSamples},${runtime},${totalsize}" >> runtime.csv

#for i in 11
#do
#    for j in {1..2}
#    do
#        n=$(( $j + 8 * ( $i - 1 ) ))
#        CUR_SEED=$(sed "${n}q;d" ${SEEDFILE})
#        probtrackx2 \
#            -x ${CUR_SEED} \
#            -s dti/${SUBJ}/dti2.bedpostX/merged \
#            -m dti/${SUBJ}/dti2.bedpostX/nodif_brain_mask \
#            --omatrix1 \
#            --os2t \
#            --otargetpaths \
#            --s2tastext \
#            -P 1000 \
#            --forcedir \
#            --opd \
#            --dir=dti/${SUBJ}/dti2.probtrackX2/results/dk.scgm/$(basename ${CUR_SEED}) \
#            --targetmasks=${SEEDFILE} &
#    done
#    wait
#done
