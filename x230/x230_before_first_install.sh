#!/bin/bash
# SPDX-License-Identifier: GPL-3.0+
# Copyright (C) 2018, Martin Kepplinger <martink@posteo.de>
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

source functions.sh
set -e

usage()
{
	echo "Skulls for the X230"
	echo "  Run this script on the X230 directly."
	echo "  It checks BIOS and hardware for relevant"
	echo "  things if you plan to install Skulls"
	echo "  please make sure dmidecode is installed"
	echo ""
	echo "Usage: $0"
}

args=$(getopt -o h -- "$@")
if [ $? -ne 0 ] ; then
	usage
	exit 1
fi

eval set -- "$args"
while [ $# -gt 0 ]
do
	case "$1" in
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

force_x230_and_root

BIOS_VENDOR=$(dmidecode -t bios | grep Vendor | cut -d':' -f2)
if [[ $BIOS_VENDOR = *"coreboot"* ]] ; then
	echo "coreboot already intalled. This script is useless then."
	exit 0
fi

BIOS_VERSION=$(dmidecode -s bios-version | grep -o '[1-2].[0-7][0-9]')
bios_major=$(echo "$BIOS_VERSION" | cut -d. -f1)
bios_minor=$(echo "$BIOS_VERSION" | cut -d. -f2)

if [ "${bios_minor}" -ge "60" ] ; then
	echo "installed BIOS version is ${bios_major}.${bios_minor}."
else
	echo -e "The installed original BIOS is very old and doesn't include the latest Embedded Controller Firmware."
	echo -e "${RED}Please upgrade${NC} before installing coreboot."
fi
