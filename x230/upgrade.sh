#!/bin/bash
# SPDX-License-Identifier: GPL-3.0+
# Copyright (C) 2018, Martin Kepplinger <martink@posteo.de>
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

set -e

source functions.sh

usage()
{
	echo "Skulls for the X230"
	echo ""
	echo "  This script checks if there's a newer"
	echo "  release of the X230 Skulls package available."
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

warn_not_root

command -v curl >/dev/null 2>&1 || { echo -e >&2 "${RED}Please install curl.${NC}"; exit 1; }

CURRENT_VERSION=$(head -2 NEWS | egrep -o "([0-9]{1,}\.)+[0-9]{1,}")

UPSTREAM_FILE=$(curl -s https://api.github.com/repos/merge/skulls/releases/latest | grep browser_download_url | cut -d'"' -f4 | cut -d'/' -f9 | head -n 1)

UPSTREAM_VERSION=$(curl -s https://api.github.com/repos/merge/skulls/releases/latest | grep browser_download_url | cut -d'"' -f4 | cut -d'/' -f9 | head -n 1 | egrep -o "([0-9]{1,}\.)+[0-9]{1,}")

UPSTREAM_X230=$(echo ${UPSTREAM_FILE} | grep x230)
if [[ -z "$UPSTREAM_X230" ]] ; then
	echo "The latest release didn't include the X230"
	exit 0
fi

if [[ "$CURRENT_VERSION" = "$UPSTREAM_VERSION" ]] ; then
	echo -e "${GREEN}You are using the latest version of Skulls for the X230${NC}"
	exit 0
elif [[ "$CURRENT_VERSION" < "$UPSTREAM_VERSION" ]] ; then
	echo -e "${RED}You have ${CURRENT_VERSION} but there is version ${UPSTREAM_VERSION} available for the X230. Please update.${NC}"
	read -r -p "Download it to the parent directory now? [y/N] " response
	case "$response" in
		[yY][eE][sS]|[yY])
			UPSTREAM_URL=$(curl -s https://api.github.com/repos/merge/skulls/releases/latest | grep browser_download_url | cut -d'"' -f4 | head -n 1)
			UPSTREAM_URL_SHA256=$(curl -s https://api.github.com/repos/merge/skulls/releases/latest | grep browser_download_url | cut -d'"' -f4 | head -n 3 | tail -n 1)
			cd ..
			curl -LO ${UPSTREAM_URL}
			curl -LO ${UPSTREAM_URL_SHA256}
			sha256sum -c ${UPSTREAM_FILE}.sha256
			mkdir skulls-x230-${UPSTREAM_VERSION}
			tar -xf ${UPSTREAM_FILE} -C skulls-x230-${UPSTREAM_VERSION}/
			echo "Version ${UPSTREAM_VERSION} extracted to ../skulls-x230-${UPSTREAM_VERSION}/"
			;;
		*)
			exit 0
		;;
	esac
else
	echo "You seem to use a development version. Please use release package skulls-x230 ${UPSTREAM_VERSION} for flashing."
fi
