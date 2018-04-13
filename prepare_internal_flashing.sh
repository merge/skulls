#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

set -e
have_input_image=0

usage()
{
	echo "Usage: $0 -i <4mb_top_image>.rom"
}

args=$(getopt -o i:h -- "$@")
if [ $? -ne 0 ] ; then
	usage
	exit 1
fi

eval set -- "$args"
while [ $# -gt 0 ]
do
	case "$1" in
	-i)
		INPUT_IMAGE=$2
		have_input_image=1
		shift
		;;
	-h)
		usage
		exit 1
		;;
	--)
		shift
		break
		;;
	*)
		echo "Invalid option: $1"
		exit 1
		;;
	esac
	shift
done

OUTPUT_IMAGE=${INPUT_IMAGE%%.*}_prepared_12mb.rom

if [ "$have_input_image" -gt 0 ] ; then
	echo "creating"
	echo "output/${OUTPUT_IMAGE}"
	echo "from"
	echo "${INPUT_IMAGE}"
echo "---------------------------------------------------------"
else
	echo "no input image provided"
	usage
	exit 1
fi

input_filesize=$(wc -c <"$INPUT_IMAGE")
reference_filesize=4194304
if [ ! "$input_filesize" -eq "$reference_filesize" ] ; then
	echo "Error: input file must be 4MB of size"
	exit 1
fi

rm -rf output
mkdir output && cd output
dd if=/dev/zero of=${OUTPUT_IMAGE} bs=4M count=2

cp ../${INPUT_IMAGE} .
dd if=${INPUT_IMAGE} oflag=append conv=notrunc of=${OUTPUT_IMAGE} bs=4M

echo "0x00000000:0x007fffff ifdmegbe" > x230-layout.txt
echo "0x00800000:0x00bfffff bios" >> x230-layout.txt

rm ${INPUT_IMAGE}

echo "---------------------------------------------------------"
echo -e "${RED}CAUTION: internal flashing is NOT encouraged${NC}"
echo ""
echo "prepared files for internal flashing in output directory."
echo "template flashrom command (please adapt the chip name) :"
echo ""
echo "cd output"
echo -e "${GREEN}flashrom -p internal:laptop=force_I_want_a_brick,spispeed=128 --layout x230-layout.txt --image bios -c "MX25L3206E" -w ${OUTPUT_IMAGE}${NC}"
