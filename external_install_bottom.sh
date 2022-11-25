#!/bin/bash
# SPDX-License-Identifier: GPL-3.0+
# Copyright (C) 2018, Martin Kepplinger <martink@posteo.de>
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

set -e

cd "$(dirname "$0")"
source "util/functions.sh"

IFDTOOL=./util/ifdtool/ifdtool
ME_CLEANER_PATH=./util/me_cleaner/me_cleaner.py
have_chipname=0
have_backupname=0
me_clean=0
lock=0
have_flasher=0
rpi_frequency=0

usage()
{
	echo "The Skulls coreboot distribution"
	echo "  Run this script on an external computer with a flasher"
	echo "  connected to the 8M (bottom) chip (on the X230 farther away from"
	echo "  the display, closer to you)."
	echo ""
	echo "Usage: $0 [-m] [-k <backup_filename>] [-l] [-f <flasher>] [-b <spispeed>] [-c <chip>]"
	echo ""
	echo " -f <hardware_flasher>   supported flashers: rpi, ch341a, tigard"
	echo " -c <chipname>           flashrom chip name to use"
	echo " -m                      apply me_cleaner -S -d"
	echo " -l                      lock the flash instead of unlocking it"
	echo " -k <backup>             save the current image as"
	echo " -s <spi frequency>      frequency of the RPi SPI bus in Hz. default: 128"
}

args=$(getopt -o f:mlc:k:hs: -- "$@")
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
	-m)
		me_clean=1
		;;
	-l)
		lock=1
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
		usage
		exit 1
		;;
	esac
	shift
done

command -v make >/dev/null 2>&1 || { echo -e >&2 "${RED}Please install make and a C compiler${NC}."; exit 1; }
command -v mktemp >/dev/null 2>&1 || { echo -e >&2 "${RED}Please install mktemp (coreutils)${NC}."; exit 1; }
command -v python >/dev/null 2>&1 || { echo -e >&2 "${RED}Please install python (or python-is-python3)${NC}."; exit 1; }

if [ ! "$have_flasher" -gt 0 ] ; then
	echo "Skulls"
	echo ""
	echo "Please select the hardware you use:"
	PS3='Please select the hardware flasher: '
	options=("Raspberry Pi" "CH341A" "Tigard" "Exit")
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
			"Tigard")
                                FLASHER="Tigard"
                                break
                                ;;

			"Exit")
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
	echo "Ok. Run this on a Rasperry Pi."
	programmer="linux_spi:dev=/dev/spidev0.0,spispeed=${rpi_frequency}"
elif [ "${FLASHER}" = "ch341a" ] ; then
	echo "Ok. Connect a CH341A programmer"
	programmer="ch341a_spi"
elif [ "${FLASHER}" = "Tigard" ] ; then
        echo "Ok. Connect a Tigard programmer"
        programmer="ft2232_spi:type=2232H,port=B,divisor=4"
else
	echo "invalid flashrom programmer"
	usage
	exit 1
fi

TEMP_DIR=$(mktemp -d)
if [ ! -d "$TEMP_DIR" ]; then
	echo -e "${RED}Error:${NC} Could not create temp dir"
	rm -rf "${TEMP_DIR}"
	exit 1
fi

if [ ! "$have_chipname" -gt 0 ] ; then
	echo "trying to detect the chip..."
	${FLASHROM} -p ${programmer} &> "${TEMP_DIR}"/chips || true
	flashrom_error=""
	flashrom_error=$(cat "${TEMP_DIR}"/chips | grep -i error || true)
	if [ ! -z "${flashrom_error}" ] ; then
		usage
		echo "-------------- flashrom error: ---------------"
		cat "${TEMP_DIR}"/chips
		rm -rf "${TEMP_DIR}"
		exit 1
	fi

	CHIPNAME=""
	chip_found=0
	if [ ! "$chip_found" -gt 0 ] ; then
		CHIPNAME=$(cat "${TEMP_DIR}"/chips | grep Found | grep "MX25L6406E/MX25L6408E" | grep -oP '"\K[^"\047]+(?=["\047])' || true)
		if [ ! -z "${CHIPNAME}" ] ; then
			chip_found=1
		fi
	fi

	if [ ! "$chip_found" -gt 0 ] ; then
		CHIPNAME=$(cat "${TEMP_DIR}"/chips | grep Found | grep "EN25QH64" | grep -o '".*"' | grep -oP '"\K[^"\047]+(?=["\047])' || true)
		if [ ! -z "${CHIPNAME}" ] ; then
			chip_found=1
		fi
	fi

	if [ ! "$chip_found" -gt 0 ] ; then
		CHIPNAME=$(cat "${TEMP_DIR}"/chips | grep Found | grep "W25Q64.V" | grep -o '".*"' | grep -oP '"\K[^"\047]+(?=["\047])' || true)
		if [ ! -z "${CHIPNAME}" ] ; then
			chip_found=1
		fi
	fi

	if [ ! "$chip_found" -gt 0 ] ; then
		echo "chip not detected."
		${FLASHROM} -p ${programmer} || true
		rm -rf "${TEMP_DIR}"
		echo "chip not detected. Please find it manually and rerun with the -c parameter."
		exit 1
	else
		echo -e "Detected ${GREEN}${CHIPNAME}${NC}."
	fi
fi

make -C util/ifdtool
if [ ! -e ${IFDTOOL} ] ; then
	echo "ifdtool not found at ${IFDTOOL}"
	exit 1
fi

if [ ! "$me_clean" -gt 0 ] ; then
	echo -e "Intel ME will ${RED}not${NC} be cleaned. Use -m if it should be."
else
	echo -e "Intel ME will be ${GREEN}cleaned${NC}."
fi

if [ ! "$lock" -gt 0 ] ; then
	echo -e "The flash ROM will be ${GREEN}unlocked${NC}."
else
	echo -e "The flash ROM will be ${RED}locked${NC}."
fi

if [ "$me_clean" -gt 0 ] ; then
	if [ ! -e ${ME_CLEANER_PATH} ] ; then
		echo "me_cleaner not found at ${ME_CLEANER_PATH}"
		rm -rf "${TEMP_DIR}"
		exit 1
	fi
fi

echo "Start reading 2 times. Please be patient..."
${FLASHROM} -p ${programmer} -c ${CHIPNAME} -r "${TEMP_DIR}"/test1.rom
${FLASHROM} -p ${programmer} -c ${CHIPNAME} -r "${TEMP_DIR}"/test2.rom
cmp "${TEMP_DIR}"/test1.rom "${TEMP_DIR}"/test2.rom
if [ "$have_backupname" -gt 0 ] ; then
	cp "${TEMP_DIR}"/test1.rom "${BACKUPNAME}"
	sha256sum "${TEMP_DIR}"/test1.rom > "${BACKUPNAME}".sha256
	echo "current image saved as ${BACKUPNAME}"
fi

reference_size=8388608
TEMP_SIZE=$(wc -c <"$TEMP_DIR/test1.rom")
if [ ! "$reference_size" -eq "$TEMP_SIZE" ] ; then
	echo -e "${RED}Error:${NC} didn't read 8M. You might be at the wrong chip."
	rm -rf "${TEMP_DIR}"
	exit 1
fi

echo -e "${GREEN}connection ok${NC}"

echo "start unlocking ..."
if [ "$me_clean" -gt 0 ] ; then
	${ME_CLEANER_PATH} -d -S -O "${TEMP_DIR}"/work.rom "${TEMP_DIR}"/test1.rom
else
	cp "${TEMP_DIR}"/test1.rom "${TEMP_DIR}"/work.rom
fi

if [ ! "$lock" -gt 0 ] ; then
	${IFDTOOL} -u "${TEMP_DIR}"/work.rom
else
	${IFDTOOL} -l "${TEMP_DIR}"/work.rom
fi

if [ ! -e "${TEMP_DIR}"/work.rom.new ] ; then
	echo -e "${RED}Error:${NC} ifdtool failed. ${TEMP_DIR}/work.rom.new not found."
	rm -rf "${TEMP_DIR}"
	exit 1
fi
if [ "$me_clean" -gt 0 ] ; then
	echo -e "${GREEN}ifdtool and me_cleaner ok${NC}"
else
	echo -e "${GREEN}ifdtool ok${NC}"
fi
make clean -C util/ifdtool

echo "start writing..."

${FLASHROM} -p ${programmer} -c "${CHIPNAME}" -w "${TEMP_DIR}"/work.rom.new
rm -rf "${TEMP_DIR}"
echo -e "${GREEN}DONE${NC}"
