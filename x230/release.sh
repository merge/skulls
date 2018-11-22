#!/bin/bash
# SPDX-License-Identifier: GPL-3.0+
# Copyright (C) 2018, Martin Kepplinger <martink@posteo.de>
#
# Script to build release-archives with. This requires a checkout from git.
# WARNING: This script is very dangerous! It may delete any untracked files.
set -e
have_version=0
have_image=0

usage()
{
        echo "Usage: $0 -v version -i release_image"
}

args=$(getopt -o v:i: -- "$@")
if [ $? -ne 0 ] ; then
        usage
        exit 1
fi
eval set -- "$args"
while [ $# -gt 0 ]
do
        case "$1" in
	-i)
		RELEASE_IMAGE=$2
		have_image=1
		shift
		;;
        -v)
                version=$2
                have_version=1
                shift
                ;;
        --)
                shift
                break
                ;;
        *)
                echo "Invalid option: $1"
                usage
                exit 1
                ;;
        esac
        shift
done

if [ ! "$have_image" -gt 0 ] ; then
	echo "please provide a release image"
	usage
	exit 1
fi

# Do we have a desired version number?
if [ "$have_version" -gt 0 ] ; then
       echo "trying to build version $version"
else
       echo "please specify a version"
       usage
       exit 1
fi

# Version number sanity check
if grep "${version}" NEWS
then
       echo "configurations seems ok"
else
       echo "please check the NEWS file"
       exit 1
fi

# Check that we are on master
branch=$(git rev-parse --abbrev-ref HEAD)
echo "we are on branch $branch"

if [ ! "${branch}" = "master" ] ; then
	echo "you don't seem to be on the master branch"
	exit 1
fi

if git diff-index --quiet HEAD --; then
	# no changes
	echo "there are no uncommitted changes (version bump)"
	exit 1
fi
echo "======================================================"
echo "    are you fine with the following version bump?"
echo "======================================================"
git diff
echo "======================================================"
read -r -p "           Press enter to continue"
echo "======================================================"

filesize=$(wc -c <"${RELEASE_IMAGE}")
reference_filesize=4194304
if [ ! "$filesize" -eq "$reference_filesize" ] ; then
	echo "filesize of release image is wrong"
	exit 1
fi

RELEASE_DIR="skulls-x230-${version}"
rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"

# copy-in the ROM
cp "${RELEASE_IMAGE}" "$RELEASE_DIR"

RELEASE_IMAGE_FILE=$(basename "${RELEASE_IMAGE}")
sha256sum ${RELEASE_DIR}/${RELEASE_IMAGE_FILE} > "${RELEASE_DIR}/${RELEASE_IMAGE_FILE}.sha256"

# copy in device independent stuff
cp ../SOURCE.md "$RELEASE_DIR"

# copy in x230 stuff
cp -a README.md NEWS util LICENSE* skulls_common.sh \
	x230_before_first_install.sh x230_skulls.sh x230_heads.sh \
	external_install_bottom.sh external_install_top.sh \
	upgrade.sh \
	"$RELEASE_DIR"

tar -cJf "$RELEASE_DIR".tar.xz "$RELEASE_DIR"

rm -rf "$RELEASE_DIR"

git commit -a -m "update to ${version}"
git tag -s "${version}" -m "skulls-x230 ${version}"

sha256sum "$RELEASE_DIR".tar.xz > "$RELEASE_DIR".tar.xz.sha256
sha512sum "$RELEASE_DIR".tar.xz > "$RELEASE_DIR".tar.xz.sha512
gpg -b -a "$RELEASE_DIR".tar.xz
