#!/bin/bash
# SPDX-License-Identifier: GPL-3.0+
# Copyright (C) 2018, Martin Kepplinger <martink@posteo.de>
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

set -e

have_input_image=0
have_chipname=0
have_backupname=0

usage()
{
	echo "Usage: $0 -i <image.rom> -c <chipname> [-k <backup_filename>]"
}

args=$(getopt -o i:c:k:h -- "$@")
if [ $? -ne 0 ] ; then
	usage
	exit 1
fi

eval set -- "$args"
while [ $# -gt 0 ]
do
	case "$1" in
	-i)
		INPUT_IMAGE_PATH=$2
		have_input_image=1
		shift
		;;
	-c)
		CHIPNAME=$2
		have_chipname=1
		shift
		;;
	-k)
		BACKUPNAME=$2
		have_backupname=1
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
	echo "no input image provided"
	usage
	exit 1
fi

if [ ! "$have_chipname" -gt 0 ] ; then
	echo "no chipname provided. To get it out, we run:"
	echo "flashrom -p linux_spi:dev=/dev/spidev0.0,spispeed=128"
	flashrom -p linux_spi:dev=/dev/spidev0.0,spispeed=128
	usage
	exit 1
fi

INPUT_IMAGE_NAME=$(basename ${INPUT_IMAGE_PATH})
INPUT_IMAGE_SIZE=$(wc -c <"$INPUT_IMAGE_PATH")
reference_filesize=4194304
if [ ! "$INPUT_IMAGE_SIZE" -eq "$reference_filesize" ] ; then
	echo -e "${RED}Error:${NC} input file must be 4MB of size"
	exit 1
fi

echo "verifying SPI connection by reading 2 times. please wait."
TEMP_DIR=`mktemp -d`
if [[ ! "$TEMP_DIR" || ! -d "$TEMP_DIR" ]]; then
	echo "Could not create temp dir"
	exit 1
fi
flashrom -p linux_spi:dev=/dev/spidev0.0,spispeed=128 -c ${CHIPNAME} -r ${TEMP_DIR}/test1.rom
flashrom -p linux_spi:dev=/dev/spidev0.0,spispeed=128 -c ${CHIPNAME} -r ${TEMP_DIR}/test2.rom
cmp --silent ${TEMP_DIR}/test1.rom ${TEMP_DIR}/test2.rom
if [ "$have_backupname" -gt 0 ] ; then
	cp ${TEMP_DIR}/test1.rom ${BACKUPNAME}
	echo "current image saved as ${BACKUPNAME}"
fi
TEMP_SIZE=$(wc -c <"$TEMP_DIR/test1.rom")
if [ ! "$INPUT_IMAGE_SIZE" -eq "$TEMP_SIZE" ] ; then
	echo -e "${RED}Error:${NC} read image (${TEMP_SIZE}) has different size that new image $INPUT_IMAGE_NAME (${INPUT_IMAGE_SIZE})"
	exit 1
fi
rm -rf ${TEMP_DIR}

echo -e "${GREEN}connection ok${NC}. flashing ${INPUT_IMAGE_NAME}"
flashrom -p linux_spi:dev=/dev/spidev0.0,spispeed=128 -c ${CHIPNAME} -w ${INPUT_IMAGE_PATH}
echo -e "${GREEN}DONE${NC}"
