#!/bin/bash
# SPDX-License-Identifier: GPL-3.0+
# Copyright (C) 2018, Martin Kepplinger <martink@posteo.de>
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

force_x230_and_root()
{
	command -v dmidecode >/dev/null 2>&1 || { echo -e >&2 "${RED}Please install dmidecode and run as root.${NC}"; exit 1; }

	local LAPTOP=$(dmidecode | grep -i x230 | sort -u)
	if [ -z "$LAPTOP" ] ; then
		echo "This is no Thinkpad X230. This script is useless then."
		exit 0
	fi
}

check_battery() {
	local capacity=$(cat /sys/class/power_supply/BAT*/capacity 2>/dev/null || echo -ne "0")
	local online=$(cat /sys/class/power_supply/AC/online 2>/dev/null || cat /sys/class/power_supply/ADP*/online 2>/dev/null || echo -ne "0")
	local failed=0

	if [ "${online}" == "0" ] ; then
		failed=1
	fi
	if [ "${capacity}" -lt 25 ]; then
		failed=1
	fi
	if [ $failed == "1" ]; then
		echo -e "${YELLOW}WARNING:${NC} To prevent shutdowns, we recommend to only run this script when"
		echo "         your laptop is plugged in to the power supply AND"
		echo "         the battery is present and sufficiently charged (over 25%)."
		while true; do
			read -r -p "Continue anyways? (please do NOT!) y/N: " yn
			case $yn in
				[Yy]* ) break;;
				[Nn]* ) exit;;
				* ) exit;;
			esac
		done
	fi
}

warn_not_root() {
	if [[ $EUID -eq 0 ]]; then
		echo -e "${RED}This script should not be run as root!${NC}"
	fi
}
