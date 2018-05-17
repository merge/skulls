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

usage()
{
	echo "Usage: $0 -c <chipname> [-m] [-k <backup_filename>] [-l]"
	echo ""
	echo "-m              apply me_cleaner -S"
	echo "-l              lock the flash instead of unlocking it"
}

args=$(getopt -o mlc:k:h -- "$@")
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

if [ ! "$have_chipname" -gt 0 ] ; then
	echo "no chipname provided. To get it, we run::"
	echo "flashrom -p linux_spi:dev=/dev/spidev0.0,spispeed=128"
	flashrom -p linux_spi:dev=/dev/spidev0.0,spispeed=128
	usage
	exit 1
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
		exit 1
	fi
fi

echo "Start reading 2 times. Please be patient..."
TEMP_DIR=`mktemp -d`
if [[ ! "$TEMP_DIR" || ! -d "$TEMP_DIR" ]]; then
	echo -e "${RED}Error:${NC} Could not create temp dir"
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
echo -e "${GREEN}DONE${NC}"
