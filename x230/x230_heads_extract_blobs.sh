#!/bin/bash
# SPDX-License-Identifier: GPL-3.0+
# Copyright (C) 2019, Martin Kepplinger <martink@posteo.de>

set -e

cd "$(dirname "$0")"

IFDTOOL=./util/ifdtool/ifdtool
ME_CLEANER=./util/me_cleaner/me_cleaner.py
have_input_image=0

usage()
{
	echo "EXPERIMENTAL"
	echo ""
	echo "This generates files for building Heads from your original 12M backup:"
	echo "  (cat bottom.bin top.bin > full_backup_image.rom)"
	echo "  ifd/me will be shrinked by me_cleaner and unlocked"
	echo ""
	echo "  http://osresearch.net"
	echo ""
	echo "Usage: $0 -f <full_backup_image>.rom -i <ifdtool>(optional) -m <me_cleaner.py(optional)"
}

args=$(getopt -o f:m:i:h -- "$@")
if [ $? -ne 0 ] ; then
	usage
	exit 1
fi

eval set -- "$args"
while [ $# -gt 0 ]
do
	case "$1" in
	-f)
		INPUT_IMAGE_PATH=$2
		have_input_image=1
		shift
		;;
	-m)
		ME_CLEANER=$2
		shift
		;;
	-i)
		IFDTOOL=$2
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

if [ ! "$have_input_image" -gt 0 ] ; then
	echo "No image file specified. Please add -f <file>"
	echo ""
	usage
	exit 1
fi

if [ ! -e ${IFDTOOL} ] ; then
	if [ ! -d util/ifdtool ] ; then
		echo "Please specify -i <ifdtool>"
		exit 1
	fi
	make -C util/ifdtool
	if [ ! -e ${IFDTOOL} ] ; then
		echo "Failed to build ifdtool"
		exit 1
	fi
fi
if [ ! -e ${ME_CLEANER} ] ; then
	mkdir -p util/me_cleaner
	curl -L https://raw.githubusercontent.com/corna/me_cleaner/v1.2/me_cleaner.py -o util/me_cleaner/me_cleaner.py
	if [ ! -e ${ME_CLEANER} ] ; then
		echo "Failed to download me_cleaner"
		exit 1
	fi
fi

OUTPUT_PATH=output
INPUT_IMAGE_NAME=$(basename "${INPUT_IMAGE_PATH}")
WORK_IMAGE_NAME=${INPUT_IMAGE_NAME%%.*}_prepared.rom

input_filesize=$(wc -c <"$INPUT_IMAGE_PATH")
reference_filesize=12582912
if [ ! "$input_filesize" -eq "$reference_filesize" ] ; then
	echo "Error: input file must be 12MB of size"
	exit 1
fi

rm -rf ${OUTPUT_PATH}
mkdir ${OUTPUT_PATH}
cp "${INPUT_IMAGE_PATH}" "${OUTPUT_PATH}/${WORK_IMAGE_NAME}"

${IFDTOOL} -x "${OUTPUT_PATH}/${WORK_IMAGE_NAME}"
mv flashregion*bin "${OUTPUT_PATH}/"
cp "${OUTPUT_PATH}/flashregion_3_gbe.bin" "${OUTPUT_PATH}/gbe.bin"
rm ${OUTPUT_PATH}/flashregion*bin

python ${ME_CLEANER} -r -t -d -S -O "${OUTPUT_PATH}/unneeded_cleaned_image.bin" -D "${OUTPUT_PATH}/ifd_shrinked.bin" -M "${OUTPUT_PATH}/me.bin" "${OUTPUT_PATH}/${WORK_IMAGE_NAME}"
rm "${OUTPUT_PATH}/unneeded_cleaned_image.bin"

${IFDTOOL} -u "${OUTPUT_PATH}/ifd_shrinked.bin"
mv "${OUTPUT_PATH}/ifd_shrinked.bin.new" "${OUTPUT_PATH}/descriptor.bin"
rm "${OUTPUT_PATH}/ifd_shrinked.bin"

rm "${OUTPUT_PATH}/${WORK_IMAGE_NAME}"

echo "done. this is what a layout file should look like:"
echo "0x00000000:0x00000fff ifd"
echo "0x00001000:0x00002fff gbe"
echo "0x00003000:0x0001afff me"
echo "0x0001b000:0x00bfffff bios"

mv ${OUTPUT_PATH}/* . && rm -rf ${OUTPUT_PATH}
