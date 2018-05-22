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
have_flasher=0

usage()
{
	echo "Skulls for the X230"
	echo "  Run this script on an external computer with a flasher"
	echo "  connected to the X230's top chip (closer to the display"
	echo "  and farther from you)"
	echo ""
	echo "Usage: $0 -i <image.rom> [-c <chipname>] [-k <backup_filename>]"
	echo ""
	echo " -f <hardware_flasher>"
	echo "       supported flashers: rpi, ch341a"
	echo ""
	echo " -i  <path to image to flash>"
	echo " -c  <chipname> to use for flashrom"
	echo " -k  <path to backup to save>"
}

args=$(getopt -o f:i:c:k:h -- "$@")
if [ $? -ne 0 ] ; then
	usage
	exit 1
fi

eval set -- "$args"
while [ $# -gt 0 ]
do
	case "$1" in
	-f)
		FLASHER=$2
		have_flasher=1
		shift
		;;
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

command -v flashrom >/dev/null 2>&1 || { echo -e >&2 "${RED}Please install flashrom and run as root${NC}."; exit 1; }

if [ ! "$have_input_image" -gt 0 ] ; then
	image_available=$(ls -1 | grep x230_coreboot_seabios | grep rom)
	if [ -z "${image_available}" ] ; then
		echo "No image file found. Please add -i <file>"
		echo ""
		usage
		exit 1
	fi

	prompt="file not specified. Please select a file to flash:"
	options=( $(find -maxdepth 1 -name x230_coreboot_seabios*rom -print0 | xargs -0) )

	PS3="$prompt "
	select INPUT_IMAGE_PATH in "${options[@]}" "Quit" ; do
		if (( REPLY == 1 + ${#options[@]} )) ; then
			exit

		elif (( REPLY > 0 && REPLY <= ${#options[@]} )) ; then
			echo  "You picked $INPUT_IMAGE_PATH which is file $REPLY"
			break

		else
			echo "Invalid option. Try another one."
		fi
	done
fi

if [ ! "$have_flasher" -gt 0 ] ; then
	echo "Please select the hardware you use:"
	PS3='Please select the hardware flasher: '
	options=("Raspberry Pi" "CH341A" "Quit")
	select opt in "${options[@]}"
	do
		case $opt in
			"Raspberry Pi")
				FLASHER="rpi"
				break
				;;
			"CH341A")
				FLASHER="ch341a"
				break
				;;
			"Quit")
				exit 0
				;;
			*) echo invalid option;;
		esac
	done
fi

programmer=""
if [ "${FLASHER}" = "rpi" ] ; then
	echo "Ok. Run this on a Rasperry Pi."
	programmer="linux_spi:dev=/dev/spidev0.0,spispeed=128"
elif [ "${FLASHER}" = "ch341a" ] ; then
	echo "Ok. Connect a CH341A programmer"
	programmer="ch341a_spi"
else
	echo "invalid flashrom programmer"
	usage
	exit 1
fi

TEMP_DIR=`mktemp -d`
if [ ! "$have_chipname" -gt 0 ] ; then
	echo "trying to detect the chip..."
	flashrom -p ${programmer} &> ${TEMP_DIR}/chips || true
	flashrom_error=""
	flashrom_error=$(cat ${TEMP_DIR}/chips | grep -i error || true)
	if [ ! -z "${flashrom_error}" ] ; then
		cat ${TEMP_DIR}/chips
		rm -rf ${TEMP_DIR}
		exit 1
	fi

	CHIPNAME=""
	chip_found=0
	CHIPNAME=$(cat ${TEMP_DIR}/chips | grep Found | grep "MX25L3206E" | grep -o '".*"' || true)
	if [ ! -z "${CHIPNAME}" ] ; then
		chip_found=1
	fi
	if [ ! "$chip_found" -gt 0 ] ; then
		echo "chip not detected."
		flashrom -p ${programmer}
		rm -rf ${TEMP_DIR}
		echo "Please find it manually in the list above and rerun with the -c parameter."
		exit 1
	else
		echo -e "Detected ${GREEN}${CHIPNAME}${NC}."
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
flashrom -p ${programmer} -c ${CHIPNAME} -r ${TEMP_DIR}/test1.rom
flashrom -p ${programmer} -c ${CHIPNAME} -r ${TEMP_DIR}/test2.rom
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
flashrom -p ${programmer} -c ${CHIPNAME} -w ${INPUT_IMAGE_PATH}
echo -e "${GREEN}DONE${NC}"
