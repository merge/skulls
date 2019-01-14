#!/bin/bash
# SPDX-License-Identifier: GPL-3.0+
# Copyright (C) 2018, Tom Hiller <thrilleratplay@gmail.com>

# shellcheck disable=SC1091
source /home/coreboot/common_scripts/variables.sh

################################################################################
## Copy config and run make
################################################################################
function configAndMake() {
  ######################
  ##   Copy config   ##
  ######################
  if [ -f "$DOCKER_COREBOOT_DIR/.config" ]; then
    echo "Using existing config"
  else
    if [ -f "$DOCKER_SCRIPT_DIR/config-$COREBOOT_COMMIT" ]; then
      cp "$DOCKER_SCRIPT_DIR/config-$COREBOOT_COMMIT" "$DOCKER_COREBOOT_DIR/.config"
      echo "Using config-$COREBOOT_COMMIT"
    elif [ -f "$DOCKER_SCRIPT_DIR/config-$COREBOOT_TAG" ]; then
      cp "$DOCKER_SCRIPT_DIR/config-$COREBOOT_TAG" "$DOCKER_COREBOOT_DIR/.config"
      echo "Using config-$COREBOOT_TAG"
    else
      cp "$DOCKER_SCRIPT_DIR/config" "$DOCKER_COREBOOT_DIR/.config"
      echo "Using default config"
    fi
  fi

  #################################
  ##  Copy in the X230 VGA BIOS  ##
  #################################
  if [ -f "$DOCKER_SCRIPT_DIR/pci8086,0166.rom" ]; then
    cp "$DOCKER_SCRIPT_DIR/pci8086,0166.rom" "$DOCKER_COREBOOT_DIR/pci8086,0166.rom"
  fi

  ###############################
  ##  Copy in bootsplash image ##
  ###############################
  if [ -f "$DOCKER_SCRIPT_DIR/bootsplash.jpg" ]; then
    cp "$DOCKER_SCRIPT_DIR/bootsplash.jpg" "$DOCKER_COREBOOT_DIR/bootsplash.jpg"
  fi

  ##############
  ##   make   ##
  ##############
  cd "$DOCKER_COREBOOT_DIR" || exit;

  if [ "$COREBOOT_CONFIG" ]; then
    make nconfig
  fi

  make
}
