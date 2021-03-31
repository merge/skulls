#!/bin/bash
# SPDX-License-Identifier: GPL-3.0+
# Copyright (C) 2018, Martin Kepplinger <martink@posteo.de>
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

set -e

cd "$(dirname "$0")"
source "util/functions.sh"

have_input_image=0
have_chipname=0
have_backupname=0
have_flasher=0
rpi_frequency=0
have_board=0
BOARD=""

usage()
{
	echo "The Skulls coreboot distribution"
	echo "  Run this script on an external computer with a flasher"
	echo "  connected to the X230's top chip (closer to the display"
	echo "  and farther from you)"
	echo ""
	echo "Usage: $0 -b (x230|x230t) [-i <image.rom>] [-c <chipname>] [-k <backup_filename>] [-f <flasher>] [-s <spispeed>]"
	echo ""
	echo " -b (x230|x230t|t430)		board to flash."
	echo " -f <hardware_flasher>   supported flashers: rpi, ch341a"
	echo " -i <image>              path to image to flash"
	echo " -c <chipname>           to use for flashrom"
	echo " -k <backup>             save the current image as"
	echo " -s <spi frequency>      frequency of the RPi SPI bus in Hz. default: 128"
}

args=$(getopt -o f:i:c:k:hs:b: -- "$@")
if [ $? -ne 0 ] ; then
	usage
	exit 1
fi

eval set -- "$args"
while [ $# -gt 0 ]
do
	case "$1" in
	-b)
		BOARD=$2
		have_board=1
		shift
		;;
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
	-s)
		rpi_frequency=$2
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

# TODO make interactive and move to functions
if [ ! "$have_board" -gt 0 ] ; then
	echo "No board specified. Please add -b <board>"
	echo ""
	usage
	exit 1
fi

if [[ $BOARD == "x230" ]] ; then
	if [[ $verbose -gt 0 ]] ; then
		echo "Board: $BOARD"
	fi
elif [[ $BOARD == "x230t" ]] ; then
	if [[ $verbose -gt 0 ]] ; then
		echo "Board: $BOARD"
	fi
elif [[ $BOARD == "t430" ]] ; then
	if [[ $verbose -gt 0 ]] ; then
		echo "Board: $BOARD"
	fi
else
	echo "Unsupported board: $BOARD"
	echo ""
	usage
	exit 1
fi

command -v flashrom >/dev/null 2>&1 || { echo -e >&2 "${RED}Please install flashrom and run as root${NC}."; exit 1; }
command -v mktemp >/dev/null 2>&1 || { echo -e >&2 "${RED}Please install mktemp (coreutils)${NC}."; exit 1; }

if [ ! "$have_input_image" -gt 0 ] ; then
	image_available=$(ls -1 | grep ${BOARD}_coreboot_seabios || true)
	if [ -z "${image_available}" ] ; then
		echo "No image file found. Please add -i <file>"
		echo ""
		usage
		exit 1
	fi

	prompt="Please select a file to flash or start with the -i option to use a different one:"
	options=( $(find -maxdepth 1 -name "${BOARD}_coreboot*rom" -print0 | xargs -0) )

	PS3="$prompt "
	select INPUT_IMAGE_PATH in "${options[@]}" "Quit" ; do
		if (( REPLY == 1 + ${#options[@]} )) ; then
			exit

		elif (( REPLY > 0 && REPLY <= ${#options[@]} )) ; then
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

if [ ! "${rpi_frequency}" -gt 0 ] ; then
	rpi_frequency=512
fi

programmer=""
if [ "${FLASHER}" = "rpi" ] ; then
	programmer="linux_spi:dev=/dev/spidev0.0,spispeed=${rpi_frequency}"
elif [ "${FLASHER}" = "ch341a" ] ; then
	programmer="ch341a_spi"
else
	echo "invalid flashrom programmer"
	usage
	exit 1
fi

TEMP_DIR=$(mktemp -d)
if [ ! -d "$TEMP_DIR" ]; then
	echo "${RED}Error:${NC} Could not create temp dir"
	exit 1
fi

if [ ! "$have_chipname" -gt 0 ] ; then
	echo "trying to detect the chip..."
	${FLASHROM} -p ${programmer} &> "${TEMP_DIR}"/chips || true
	flashrom_error=""
	flashrom_error=$(cat "${TEMP_DIR}"/chips | grep -i error || true)
	if [ ! -z "${flashrom_error}" ] ; then
		cat "${TEMP_DIR}"/chips
		rm -rf "${TEMP_DIR}"
		exit 1
	fi

	CHIPNAME=""
	chip_found=0
	if [ ! "$chip_found" -gt 0 ] ; then
		CHIPNAME=$(cat "${TEMP_DIR}"/chips | grep Found | grep MX25L3206E | grep -oP '"\K[^"\047]+(?=["\047])' || true)
		if [ ! -z "${CHIPNAME}" ] ; then
			chip_found=1
		fi
	fi

	if [ ! "$chip_found" -gt 0 ] ; then
		CHIPNAME=$(cat "${TEMP_DIR}"/chips | grep Found | grep EN25QH32 | grep -oP '"\K[^"\047]+(?=["\047])' || true)
		if [ ! -z "${CHIPNAME}" ] ; then
			chip_found=1
		fi
	fi

	if [ ! "$chip_found" -gt 0 ] ; then
		CHIPNAME=$(cat "${TEMP_DIR}"/chips | grep Found | grep W25Q32.V | grep -o '".*"' | grep -oP '"\K[^"\047]+(?=["\047])' || true)
		if [ ! -z "${CHIPNAME}" ] ; then
			chip_found=1
		fi
	fi

	if [ ! "$chip_found" -gt 0 ] ; then
		echo "chip not detected."
		${FLASHROM} -p ${programmer} || true
		rm -rf "${TEMP_DIR}"
		echo "Please find it manually in the list above and rerun with the -c parameter."
		exit 1
	else
		echo -e "Detected ${GREEN}${CHIPNAME}${NC}."
	fi
fi

INPUT_IMAGE_NAME=$(basename "${INPUT_IMAGE_PATH}")
INPUT_IMAGE_SIZE=$(wc -c < "$INPUT_IMAGE_PATH")
reference_filesize=4194304
if [ ! "$INPUT_IMAGE_SIZE" -eq "$reference_filesize" ] ; then
	echo -e "${RED}Error:${NC} input file must be 4MB of size"
	exit 1
fi

echo "verifying SPI connection by reading 2 times. please wait."
${FLASHROM} -p ${programmer} -c ${CHIPNAME} -r ${TEMP_DIR}/test1.rom
${FLASHROM} -p ${programmer} -c ${CHIPNAME} -r ${TEMP_DIR}/test2.rom
cmp --silent "${TEMP_DIR}"/test1.rom "${TEMP_DIR}"/test2.rom
if [ "$have_backupname" -gt 0 ] ; then
	cp "${TEMP_DIR}"/test1.rom "${BACKUPNAME}"
	sha256sum "${TEMP_DIR}"/test1.rom > "${BACKUPNAME}".sha256
	echo "current image saved as ${BACKUPNAME}"
fi
TEMP_SIZE=$(wc -c < "$TEMP_DIR/test1.rom")
if [ ! "$INPUT_IMAGE_SIZE" -eq "$TEMP_SIZE" ] ; then
	echo -e "${RED}Error:${NC} read image (${TEMP_SIZE}) has different size that new image $INPUT_IMAGE_NAME (${INPUT_IMAGE_SIZE})"
	exit 1
fi
rm -rf "${TEMP_DIR}"

echo -e "${GREEN}connection ok${NC}. flashing ${INPUT_IMAGE_NAME}"
${FLASHROM} -p ${programmer} -c "${CHIPNAME}" -w "${INPUT_IMAGE_PATH}"
echo -e "${GREEN}DONE${NC}"
