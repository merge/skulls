#!/bin/bash
# SPDX-License-Identifier: GPL-3.0+
# Copyright (C) 2018, Martin Kepplinger <martink@posteo.de>
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

set -e

usage()
{
	echo "Usage: $0"
	echo ""
	echo "please make sure dmidecode is installed"
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

hash dmidecode

LAPTOP=$(dmidecode | grep -i x230 | sort -u)
if [ -z $LAPTOP ] ; then
	echo "This is no Thinkpad X230. This script is useless then."
	exit 0
fi

BIOS_VENDOR=$(dmidecode -t bios | grep Vendor)
if [[ $BIOS_VENDOR = *"oreboot"* ]] ; then
	echo "coreboot already intalled. This script is only useful when an original BIOS is installed."
	exit 0
fi

dmidecode -s bios-version
BIOS_VERSION=$(dmidecode -s bios-version | grep -o '[0-9][0-9]')
if [ "${BIOS_VERSION}" = "72" ] ; then
	echo "latest original BIOS version installed. Nothing to do."
elif [ "${BIOS_VERSION}" -gt "60" ] ; then
	echo "original BIOS is not the latest version, but the EC version is."
	echo "You may upgrade before installing coreboot if you want."
else
	echo -e "The installed original BIOS is very old. ${RED}please upgrade${NC} before installing coreboot."
fi

echo "Please search for your SODIMM RAM and verify that it uses 1,5 Volts (not 1,35V):"
dmidecode -t memory | grep Part | grep -v "Not Specified" | sort -u | cut -d':' -f2 | sed 's/ //'
