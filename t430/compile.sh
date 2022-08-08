#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0+
# Copyright (C) 2018, Tom Hiller <thrilleratplay@gmail.com>

# shellcheck disable=SC1091
source /home/coreboot/common_scripts/variables.sh
source /home/coreboot/common_scripts/download_coreboot.sh
source /home/coreboot/common_scripts/config_and_make.sh

################################################################################
## MODEL VARIABLES
################################################################################
MAINBOARD="lenovo"
MODEL="t430"

################################################################################

###############################################
##   download/git clone/git pull Coreboot    ##
###############################################
downloadOrUpdateCoreboot

##############################
##   Copy config and make   ##
##############################
configAndMake

#####################
##   Post build    ##
#####################
if [ ! -f "$DOCKER_COREBOOT_DIR/build/coreboot.rom" ]; then
  echo "Uh oh. Things did not go according to plan."
  exit 1;
else
  #split out top BIOS
  if [ ! -z "$COREBOOT_COMMIT" ]; then
    RELEASEFILE="${MODEL}_coreboot_seabios_$(echo ${COREBOOT_COMMIT} | cut -c 1-10)_top.rom"
  else
    RELEASEFILE="coreboot_$MAINBOARD-$MODEL-top.rom"
  fi
  dd if="$DOCKER_COREBOOT_DIR/build/coreboot.rom" of="$DOCKER_COREBOOT_DIR/$RELEASEFILE" bs=1M skip=8
  sha256sum "$DOCKER_COREBOOT_DIR/$RELEASEFILE" > "$DOCKER_COREBOOT_DIR/${RELEASEFILE}".sha256
  echo "==================== result: ======================"
  echo "$DOCKER_COREBOOT_DIR/$RELEASEFILE"
  echo "==================================================="
fi
