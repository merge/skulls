#!/bin/bash
# SPDX-License-Identifier: GPL-3.0+
# Copyright (C) 2019, Martin Kepplinger <martink@posteo.de>

set -e

cd "$(dirname "$0")"

source "util/functions.sh"

have_input_image=0
request_update=0
verbose=0
have_board=0
BOARD=""

usage()
{
	echo "The Skulls coreboot distribution:"
	echo "  Run this script on the Laptop directly."
	echo ""
	echo "  This flashes the BIOS with the given image."
	echo "  Make sure you booted Linux with iomem=relaxed"
	echo ""
	echo "Usage: $0 -b (x230|x230t|t430) [-i <4mb_top_image>.rom] [-U] [-h]"
	echo "Options:"
	echo "  -b	board to flash. This must be \"x230\", \"x230t\" or \"t430\""
	echo "  -i	path to the image to flash"
	echo "  -U	update: check for a new Skulls package online"
	echo "  -v	verbose output. prints more information"
	echo "  -h	print this help text"
}

args=$(getopt -o b:i:hUv -- "$@")
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
	-i)
		INPUT_IMAGE_PATH=$2
		have_input_image=1
		shift
		;;
	-h)
		usage
		exit 1
		;;
	-U)
		request_update=1
		;;
	-v)
		verbose=1
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

if [ "$request_update" -gt 0 ] ; then
	warn_not_root

	command -v curl >/dev/null 2>&1 || { echo -e >&2 "${RED}Please install curl.${NC}"; exit 1; }

	CURRENT_VERSION=$(head -2 NEWS | egrep -o "([0-9]{1,}\.)+[0-9]{1,}")

	UPSTREAM_FILE=$(curl -s https://api.github.com/repos/merge/skulls/releases | grep browser_download_url | cut -d'"' -f4 | cut -d'/' -f9 | head -n 1)

	UPSTREAM_VERSION=$(curl -s https://api.github.com/repos/merge/skulls/releases | grep browser_download_url | cut -d'"' -f4 | cut -d'/' -f9 | head -n 1 | egrep -o "([0-9]{1,}\.)+[0-9]{1,}")

	if [[ $verbose -gt 0 ]] ; then
		echo "This is v$CURRENT_VERSION and latest is v$UPSTREAM_VERSION"
	fi

	if [[ "$CURRENT_VERSION" = "$UPSTREAM_VERSION" ]] ; then
		echo -e "${GREEN}You are using the latest version of Skulls${NC}"
		exit 0
	elif [[ "$CURRENT_VERSION" < "$UPSTREAM_VERSION" ]] ; then
		echo -e "${RED}You have ${CURRENT_VERSION} but there is version ${UPSTREAM_VERSION} available. Please update.${NC}"
		read -r -p "Download it to the parent directory now? [y/N] " response
		case "$response" in
			[yY][eE][sS]|[yY])
				UPSTREAM_URL=$(curl -s https://api.github.com/repos/merge/skulls/releases | grep browser_download_url | cut -d'"' -f4 | head -n 1)
				UPSTREAM_URL_SHA256=$(curl -s https://api.github.com/repos/merge/skulls/releases | grep browser_download_url | cut -d'"' -f4 | head -n 3 | tail -n 1)
				cd ..
				curl -LO ${UPSTREAM_URL}
				curl -LO ${UPSTREAM_URL_SHA256}
				sha256sum -c ${UPSTREAM_FILE}.sha256
				mkdir skulls-$BOARD-${UPSTREAM_VERSION}
				tar -xf ${UPSTREAM_FILE}
				echo "Version ${UPSTREAM_VERSION} extracted to ../skulls-$BOARD-${UPSTREAM_VERSION}/"
				echo "Please continue in the new directory."
				;;
			*)
				exit 0
			;;
		esac
	else
		echo "You seem to use a development version. Please use release package skulls-$BOARD ${UPSTREAM_VERSION} for flashing."
	fi

	exit 0
fi

check_board_and_root

BIOS_VENDOR=$(${DMIDECODE} -t bios | grep Vendor | cut -d':' -f2)
if [[ $BIOS_VENDOR != *"coreboot"* ]] ; then
	BIOS_VERSION=$(${DMIDECODE} -s bios-version | grep -o '[1-2].[0-7][0-9]')
	bios_major=$(echo "$BIOS_VERSION" | cut -d. -f1)
	bios_minor=$(echo "$BIOS_VERSION" | cut -d. -f2)

	if [ "${bios_minor}" -ge "61" ] ; then
		echo "Ready to use external_install_bottom.sh and external_install_top.sh"
		echo "Please run both scripts from a different computer with a"
		echo "hardware SPI flasher."
	else
		echo -e "The installed original BIOS is very old."
		echo -e "${RED}Please upgrade${NC} from lenovo.com before installing coreboot."
	fi
	exit 0
fi

if [[ "$verbose" -gt 0 ]] ; then
	if [ -d "/sys/class/power_supply/BAT0" ] ; then
		bat_last_full=$(cat /sys/class/power_supply/BAT0/charge_full)
		bat_design_cap=$(cat /sys/class/power_supply/BAT0/charge_full_design)
		bat_health=$(echo "scale=2 ; $bat_last_full/$bat_design_cap" | bc | sed 's/^\./0./')
		bat_health=$(echo "$bat_health*100" | bc)
		echo "INFO: Battery hardware health is $bat_health%"
	fi
fi

if [ ! "$have_input_image" -gt 0 ] ; then
	image_available=$(ls -1 | grep ${BOARD}_coreboot_seabios || true)
	if [ -z "${image_available}" ] ; then
		echo "No image file found. Please add -i <file>"
		echo ""
		usage
		exit 1
	fi

	prompt="file not specified. Please select a file to flash. Please read the README for details about the differences:"
	options=( $(find -maxdepth 1 -name "${BOARD}_coreboot_seabios*rom" -print0 | xargs -0) )

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


OUTPUT_PATH=output
INPUT_IMAGE_NAME=$(basename "${INPUT_IMAGE_PATH}")
OUTPUT_IMAGE_NAME=${INPUT_IMAGE_NAME%%.*}_prepared_12mb.rom
OUTPUT_IMAGE_PATH=${OUTPUT_PATH}/${OUTPUT_IMAGE_NAME}

echo -e "input: ${INPUT_IMAGE_NAME}"
echo -e "output: ${OUTPUT_IMAGE_PATH}"

input_filesize=$(wc -c <"$INPUT_IMAGE_PATH")
reference_filesize=4194304
if [ ! "$input_filesize" -eq "$reference_filesize" ] ; then
	echo "Error: input file must be 4MB of size"
	exit 1
fi

rm -rf ${OUTPUT_PATH}
mkdir ${OUTPUT_PATH}

dd if=/dev/zero of="${OUTPUT_IMAGE_PATH}" bs=4M count=2 status=none
dd if="${INPUT_IMAGE_PATH}" oflag=append conv=notrunc of="${OUTPUT_IMAGE_PATH}" bs=4M status=none

LAYOUT_FILENAME="layout.txt"

echo "0x00000000:0x00000fff ifd" > ${OUTPUT_PATH}/${LAYOUT_FILENAME}
echo "0x00001000:0x00002fff gbe" >> ${OUTPUT_PATH}/${LAYOUT_FILENAME}
echo "0x00003000:0x004fffff me" >> ${OUTPUT_PATH}/${LAYOUT_FILENAME}
echo "0x00500000:0x007fffff unused" >> ${OUTPUT_PATH}/${LAYOUT_FILENAME}
echo "0x00800000:0x00bfffff bios" >> ${OUTPUT_PATH}/${LAYOUT_FILENAME}

echo -e "${YELLOW}WARNING${NC}: Make sure not to power off your computer or interrupt this process in any way!"
echo -e "         Interrupting this process may result in irreparable damage to your computer!"
check_battery
while true; do
	read -r -p "Flash the BIOS now? y/N: " yn
	case $yn in
		[Yy]* ) cd ${OUTPUT_PATH} && ${FLASHROM} --force --noverify-all -p internal --layout ${LAYOUT_FILENAME} --image bios -w "${OUTPUT_IMAGE_NAME}"; break;;
		[Nn]* ) exit;;
		* ) exit;;
	esac
done

rm -rf ${OUTPUT_PATH}

while true; do
	read -r -p "Power off now? (please do!) Y/n: " yn
	case $yn in
		[Yy]* ) poweroff ;;
		[Nn]* ) exit;;
		* ) poweroff ;;
	esac
done
