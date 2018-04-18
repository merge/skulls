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

usage()
{
	echo "Usage: $0 -c <chipname> [-m] [-k <backup_filename>]"
	echo ""
	echo "-m              apply me_cleaner -S"
}

args=$(getopt -o mc:k:h -- "$@")
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
	echo "no chipname provided. to find it out, run:"
	echo "flashrom -p linux_spi:dev=/dev/spidev0.0,spispeed=128"
	usage
	exit 1
fi

make -C util/ifdtool
if [ ! -e ${IFDTOOL_PATH} ] ; then
	echo "ifdtool not found at ${IFDTOOL_PATH}"
	exit 1
fi

if [ ! "$me_clean" -gt 0 ] ; then
	echo "Intel ME will NOT be cleaned. Use -m if it should be."
else
	echo "Intel ME will be cleaned."
fi

if [ "$me_clean" -gt 0 ] ; then
	if [ ! -e ${ME_CLEANER_PATH} ] ; then
		echo "me_cleaner not found at ${ME_CLEANER_PATH}"
		exit 1
	fi
fi

echo "start reading ..."
TEMP_DIR=`mktemp -d`
if [[ ! "$TEMP_DIR" || ! -d "$TEMP_DIR" ]]; then
	echo -e "${RED}Error:${NC} Could not create temp dir"
	exit 1
fi
flashrom -p linux_spi:dev=/dev/spidev0.0,spispeed=128 -c ${CHIPNAME} -r ${TEMP_DIR}/test1.rom
flashrom -p linux_spi:dev=/dev/spidev0.0,spispeed=128 -c ${CHIPNAME} -r ${TEMP_DIR}/test2.rom
cmp --silent ${TEMP_DIR}/test1.rom ${TEMP_DIR}/test2.rom
if [ "$have_backupname" -gt 0 ] ; then
	mv ${TEMP_DIR}/test1.rom ${BACKUPNAME}
	echo "current image saved as ${BACKUPIMAGE}"
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

${IFDTOOL_PATH} -u ${TEMP_DIR}/work.rom
if if [ ! -e ${TEMP_DIR}/work.rom.new ] ; then
	echo -e "${RED}Error:${NC} Unlocking failed. ${TEMP_DIR}/work.rom.new not found."
	rm -rf ${TEMP_DIR}
	exit 1
fi
if [ "$me_clean" -gt 0 ] ; then
	echo -e "${GREEN}unlock and me_cleaner ok${NC}"
else
	echo -e "${GREEN}unlock ok${NC}"
fi
make clean -C util/ifdtool

echo "start writing..."
flashrom -p linux_spi:dev=/dev/spidev0.0,spispeed=128 -c ${CHIPNAME} -w ${TEMP_DIR}/work.rom.new
echo -e "${GREEN}DONE${NC}"
