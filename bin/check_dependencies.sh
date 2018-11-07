#! /bin/bash
# Check for any software dependencies
# Christopher G. Watson, 2018-11-03

source utilities.sh

# Check for dcm2niix
check_sw dcm2niix dcm2niix 3

# Check for ImageMagick
check_sw convert "the 'ImageMagick' suite" 4

# Check for jo
check_sw jo jo 5

# Check for dcmtk tools
check_sw dcmdump "the 'DCMTK' library" 6

# Check for FSL
check_sw fsl "the latest version of 'FSL'" 7

# Check for jq
check_sw jq jq 8

tput sgr0
