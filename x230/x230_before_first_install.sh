#!/bin/bash
# SPDX-License-Identifier: GPL-3.0+
# Copyright (C) 2018, Martin Kepplinger <martink@posteo.de>
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

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

hash dmidecode

LAPTOP=$(dmidecode | grep -i x230 | sort -u)
if [ -z "$LAPTOP" ] ; then
	echo "This is no Thinkpad X230. This script is useless then."
	exit 0
fi

BIOS_VENDOR=$(dmidecode -t bios | grep Vendor | cut -d':' -f2)
if [[ $BIOS_VENDOR = *"coreboot"* ]] ; then
	echo "coreboot already intalled. This script is useless then."
	exit 0
fi

BIOS_VERSION=$(dmidecode -s bios-version | grep -o '[1-2].[0-7][0-9]')
bios_major=$(echo $BIOS_VERSION | cut -d. -f1)
bios_minor=$(echo $BIOS_VERSION | cut -d. -f2)

if [ "${bios_minor}" -eq "72" ] ; then
	echo "latest BIOS version installed. Nothing to do."
elif [ "${bios_minor}" -ge "60" ] ; then
	echo "installed BIOS version is ${bios_major}.${bios_minor}."
	echo "That's not the latest version, but the EC version is."
	echo "You may upgrade before installing coreboot if you want."
else
	echo -e "The installed original BIOS is very old. ${RED}please upgrade${NC} before installing coreboot."
fi

echo "Please search for your SODIMM RAM and verify that it uses 1,5 Volts (not 1,35V):"
dmidecode -t memory | grep Part | grep -v "Not Specified" | sort -u | cut -d':' -f2 | sed 's/ //'
RAM_SPEC=$(dmidecode -t memory | grep Part | grep -v "Not Specified" | sort -u | cut -d':' -f2 | sed 's/ //')

read -r -p "Open a browser and search for it? [y/N] " response
case "$response" in
	[yY][eE][sS]|[yY])
		xdg-open "https://duckduckgo.com/?q=${RAM_SPEC}!"
		;;
	*)
		exit 0
	;;
esac
