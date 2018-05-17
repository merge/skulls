#!/bin/bash
# SPDX-License-Identifier: GPL-3.0+
# Copyright (C) 2018, Martin Kepplinger <martink@posteo.de>
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

set -e

IFDTOOL_PATH=./util/ifdtool/ifdtool
ME_CLEANER_PATH=./util/me_cleaner/me_cleaner.py
have_chipname=0
have_backupname=0
me_clean=0
lock=0
autodetect_chip=0

usage()
{
	echo "Usage: $0 [-c <chipname>] [-a] [-m] [-k <backup_filename>] [-l]"
	echo ""
	echo "-c <chipname>   flashrom chip description to use"
	echo "-a              try to autodetect the chipname"
	echo "-m              apply me_cleaner -S"
	echo "-l              lock the flash instead of unlocking it"
	echo "-k <file>       save the read image as <file>"
}

args=$(getopt -o mlc:ak:h -- "$@")
if [ $? -ne 0 ] ; then
	usage
	exit 1
fi

eval set -- "$args"
while [ $# -gt 0 ]
do
	case "$1" in
	-m)
		me_clean=1
		;;
	-l)
		lock=1
		;;
	-a)
		autodetect_chip=1
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
		flashrom_error=$(cat ${TEMP_DIR}/chips | grep -i error || true)
		if [ ! -z "${flashrom_error}" ] ; then
			cat ${TEMP_DIR}/chips
			rm -rf ${TEMP_DIR}
			exit 1
		fi

		CHIPNAME=""
		chip_found=0
		CHIPNAME=$(cat ${TEMP_DIR}/chips | grep Found | grep "MX25L6406E/MX25L6408E" | grep -o '".*"' || true)
		if [ ! -z "${CHIPNAME}" ] ; then
			chip_found=1
		fi
		CHIPNAME=$(cat ${TEMP_DIR}/chips | grep Found | grep "EN25QH64" | grep -o '".*"' || true)
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

make -C util/ifdtool
if [ ! -e ${IFDTOOL_PATH} ] ; then
	echo "ifdtool not found at ${IFDTOOL_PATH}"
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
		rm -rf ${TEMP_DIR}
		exit 1
	fi
fi

echo "Start reading 2 times. Please be patient..."
if [[ ! "$TEMP_DIR" || ! -d "$TEMP_DIR" ]]; then
	echo -e "${RED}Error:${NC} Could not create temp dir"
	rm -rf ${TEMP_DIR}
	exit 1
fi
flashrom -p linux_spi:dev=/dev/spidev0.0,spispeed=128 -c ${CHIPNAME} -r ${TEMP_DIR}/test1.rom
flashrom -p linux_spi:dev=/dev/spidev0.0,spispeed=128 -c ${CHIPNAME} -r ${TEMP_DIR}/test2.rom
cmp --silent ${TEMP_DIR}/test1.rom ${TEMP_DIR}/test2.rom
if [ "$have_backupname" -gt 0 ] ; then
	cp ${TEMP_DIR}/test1.rom ${BACKUPNAME}
	echo "current image saved as ${BACKUPNAME}"
fi

reference_size=8388608
TEMP_SIZE=$(wc -c <"$TEMP_DIR/test1.rom")
if [ ! "$reference_size" -eq "$TEMP_SIZE" ] ; then
	echo -e "${RED}Error:${NC} didn't read 8M. You might be at the wrong chip."
	rm -rf ${TEMP_DIR}
	exit 1
fi

echo -e "${GREEN}connection ok${NC}"

echo "start unlocking ..."
if [ "$me_clean" -gt 0 ] ; then
	${ME_CLEANER_PATH} -S -O ${TEMP_DIR}/work.rom ${TEMP_DIR}/test1.rom
else
	cp ${TEMP_DIR}/test1.rom ${TEMP_DIR}/work.rom
fi

if [ ! "$lock" -gt 0 ] ; then
	${IFDTOOL_PATH} -u ${TEMP_DIR}/work.rom
else
	${IFDTOOL_PATH} -l ${TEMP_DIR}/work.rom
fi

if [ ! -e ${TEMP_DIR}/work.rom.new ] ; then
	echo -e "${RED}Error:${NC} ifdtool failed. ${TEMP_DIR}/work.rom.new not found."
	rm -rf ${TEMP_DIR}
	exit 1
fi
if [ "$me_clean" -gt 0 ] ; then
	echo -e "${GREEN}ifdtool and me_cleaner ok${NC}"
else
	echo -e "${GREEN}ifdtool ok${NC}"
fi
make clean -C util/ifdtool

echo "start writing..."
flashrom -p linux_spi:dev=/dev/spidev0.0,spispeed=128 -c ${CHIPNAME} -w ${TEMP_DIR}/work.rom.new
rm -rf ${TEMP_DIR}
echo -e "${GREEN}DONE${NC}"
