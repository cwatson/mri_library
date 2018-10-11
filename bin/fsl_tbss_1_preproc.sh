#! /bin/bash
#
# Function to perform TBSS step 1 on a single subject; makes it easier to
# parallelize for the cluster.
#_______________________________________________________________________________
# Chris Watson, 2017-05-04

subj=$(imglob $1)

X=$(${FSLDIR}/bin/fslval $subj dim1); X=$(echo "$X 2 - p" | dc -)
Y=$(${FSLDIR}/bin/fslval $subj dim2); Y=$(echo "$Y 2 - p" | dc -)
Z=$(${FSLDIR}/bin/fslval $subj dim3); Z=$(echo "$Z 2 - p" | dc -)
$FSLDIR/bin/fslmaths $subj -min 1 -ero -roi 1 $X 1 $Y 1 $Z 0 1 FA/${subj}_FA

# create mask (for use in FLIRT & FNIRT)
$FSLDIR/bin/fslmaths FA/${subj}_FA -bin FA/${subj}_FA_mask

$FSLDIR/bin/fslmaths FA/${subj}_FA_mask -dilD -dilD -sub 1 -abs -add FA/${subj}_FA_mask FA/${subj}_FA_mask -odt char

$FSLDIR/bin/immv $subj origdata
