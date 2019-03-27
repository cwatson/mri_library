#! /bin/bash
# Check for any software dependencies
# Christopher G. Watson, 2018-11-03

source utilities.sh

# Check for dcm2niix
check_sw dcm2niix dcm2niix 64

# Check for ImageMagick
check_sw convert "the 'ImageMagick' suite" 65

# Check for jo
check_sw jo jo 66

# Check for dcmtk tools
check_sw dcmdump "the 'DCMTK' library" 67

# Check for FSL
check_sw fsl "the latest version of 'FSL'" 68

# Check for jq
check_sw jq jq 69

# Check for eddyQC
check_sw eddy_quad eddyQC 70

tput sgr0
