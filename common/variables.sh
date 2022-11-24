#!/bin/bash
# SPDX-License-Identifier: GPL-3.0+
# Copyright (C) 2018, Tom Hiller <thrilleratplay@gmail.com>

################################################################################
## VARIABLES
################################################################################
export COREBOOT_SDK_VERSION="2022-09-18_c8870b1334"

export DOCKER_ROOT_DIR="/home/coreboot"
export DOCKER_SCRIPT_DIR="$DOCKER_ROOT_DIR/scripts"
export DOCKER_COMMON_SCRIPT_DIR="$DOCKER_ROOT_DIR/common_scripts"
export DOCKER_COREBOOT_DIR="$DOCKER_ROOT_DIR/cb_build"
export DOCKER_COREBOOT_CONFIG_DIR="$DOCKER_COREBOOT_DIR/configs"
