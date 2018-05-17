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
autodetect_chip=0

usage()
{
	echo "Usage: $0 -i <image.rom> [-c <chipname>] [-a] [-k <backup_filename>]"
	echo ""
	echo " -i  <path to image to flash>"
	echo " -c  <chipname> for flashrom"
	echo " -a  ... try autodetecting the chipname"
	echo " -k  <path to backup to save>"
}

args=$(getopt -o i:c:ak:h -- "$@")
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
	-a)
		autodetect_chip=1
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

TEMP_DIR=`mktemp -d`
if [ ! "$have_chipname" -gt 0 ] ; then
	if [ ! "$autodetect_chip" -gt 0 ] ; then
		echo -e "${RED}no chipname provided${NC}. To get it, we run:"
		echo "flashrom -p linux_spi:dev=/dev/spidev0.0,spispeed=128"
		flashrom -p linux_spi:dev=/dev/spidev0.0,spispeed=128
		usage
		rm -rf ${TEMP_DIR}
		exit 1
	else
		echo "trying to detect the chip..."
		flashrom -p linux_spi:dev=/dev/spidev0.0,spispeed=128 &> ${TEMP_DIR}/chips || true
		flashrom_error=""
		flashrom_error=$(cat ${TEMP_DIR}/chips | grep -i error)
		if [ ! -z "${flashrom_error}" ] ; then
			cat ${TEMP_DIR}/chips
			rm -rf ${TEMP_DIR}
			exit 1
		fi

		CHIPNAME=""
		chip_found=0
		CHIPNAME=$(cat ${TEMP_DIR}/chips | grep Found | grep "MX25L3206E" | grep -o '".*"')
		if [ ! -z "${CHIPNAME}" ] ; then
			chip_found=1
		fi
		if [ ! "$chip_found" -gt 0 ] ; then
			echo -e "${RED}Error:${NC} chip not detected. Please find it manually:"
			flashrom -p linux_spi:dev=/dev/spidev0.0,spispeed=128
			rm -rf ${TEMP_DIR}
			exit 1
		else
			echo -e "Detected ${GREEN}${CHIPNAME}${NC}."
		fi
	fi
fi

INPUT_IMAGE_NAME=$(basename ${INPUT_IMAGE_PATH})
INPUT_IMAGE_SIZE=$(wc -c <"$INPUT_IMAGE_PATH")
reference_filesize=4194304
if [ ! "$INPUT_IMAGE_SIZE" -eq "$reference_filesize" ] ; then
	echo -e "${RED}Error:${NC} input file must be 4MB of size"
	exit 1
fi

echo "verifying SPI connection by reading 2 times. please wait."
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
