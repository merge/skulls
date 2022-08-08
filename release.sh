#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0+
# Copyright (C) 2018, Martin Kepplinger <martink@posteo.de>
#
# Script to build release-archives with. This requires a checkout from git.
# WARNING: This script is very dangerous! It may delete any untracked files.
set -e
have_version=0
have_image=0
have_image_2=0
have_image_3=0
have_image_4=0
have_image_5=0
have_image_6=0
have_image_7=0

usage()
{
        echo "Usage: $0 -v version -i img -f img -g img -h img -j img -k img -l img"
}

args=$(getopt -o v:i:f:g:h:j:k:l: -- "$@")
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
	-f)
		RELEASE_IMAGE_2=$2
		have_image_2=1
		shift
		;;
	-g)
		RELEASE_IMAGE_3=$2
		have_image_3=1
		shift
		;;
	-h)
		RELEASE_IMAGE_4=$2
		have_image_4=1
		shift
		;;
	-j)
		RELEASE_IMAGE_5=$2
		have_image_5=1
		shift
		;;
	-k)
		RELEASE_IMAGE_6=$2
		have_image_6=1
		shift
		;;
	-l)
		RELEASE_IMAGE_7=$2
		have_image_7=1
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
	echo "image missing"
	usage
	exit 1
fi
if [ ! "$have_image_2" -gt 0 ] ; then
	echo "image missing"
	usage
	exit 1
fi

if [ ! "$have_image_3" -gt 0 ] ; then
	echo "image missing"
	usage
	exit 1
fi
if [ ! "$have_image_4" -gt 0 ] ; then
	echo "image missing"
	usage
	exit 1
fi
if [ ! "$have_image_5" -gt 0 ] ; then
	echo "image missing"
	usage
	exit 1
fi
if [ ! "$have_image_6" -gt 0 ] ; then
	echo "image missing"
	usage
	exit 1
fi
if [ ! "$have_image_7" -gt 0 ] ; then
	echo "image missing"
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
filesize=$(wc -c <"${RELEASE_IMAGE_2}")
reference_filesize=4194304
if [ ! "$filesize" -eq "$reference_filesize" ] ; then
	echo "filesize of release image is wrong"
	exit 1
fi

filesize=$(wc -c <"${RELEASE_IMAGE_3}")
reference_filesize=4194304
if [ ! "$filesize" -eq "$reference_filesize" ] ; then
	echo "filesize of release image is wrong"
	exit 1
fi
filesize=$(wc -c <"${RELEASE_IMAGE_4}")
reference_filesize=4194304
if [ ! "$filesize" -eq "$reference_filesize" ] ; then
	echo "filesize of release image is wrong"
	exit 1
fi
filesize=$(wc -c <"${RELEASE_IMAGE_5}")
reference_filesize=4194304
if [ ! "$filesize" -eq "$reference_filesize" ] ; then
	echo "filesize of release image is wrong"
	exit 1
fi
filesize=$(wc -c <"${RELEASE_IMAGE_6}")
reference_filesize=4194304
if [ ! "$filesize" -eq "$reference_filesize" ] ; then
	echo "filesize of release image is wrong"
	exit 1
fi
filesize=$(wc -c <"${RELEASE_IMAGE_7}")
reference_filesize=4194304
if [ ! "$filesize" -eq "$reference_filesize" ] ; then
	echo "filesize of release image is wrong"
	exit 1
fi


RELEASE_DIR="skulls-${version}"
rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"

# copy-in the ROMs
cp "${RELEASE_IMAGE}" "$RELEASE_DIR"
cp "${RELEASE_IMAGE_2}" "$RELEASE_DIR"
cp "${RELEASE_IMAGE_3}" "$RELEASE_DIR"
cp "${RELEASE_IMAGE_4}" "$RELEASE_DIR"
cp "${RELEASE_IMAGE_5}" "$RELEASE_DIR"
cp "${RELEASE_IMAGE_6}" "$RELEASE_DIR"
cp "${RELEASE_IMAGE_7}" "$RELEASE_DIR"

RELEASE_IMAGE_FILE=$(basename "${RELEASE_IMAGE}")
cd ${RELEASE_DIR}
sha256sum ${RELEASE_IMAGE_FILE} > "${RELEASE_IMAGE_FILE}.sha256"
RELEASE_IMAGE_FILE_2=$(basename "${RELEASE_IMAGE_2}")
sha256sum ${RELEASE_IMAGE_FILE_2} > "${RELEASE_IMAGE_FILE_2}.sha256"
RELEASE_IMAGE_FILE_3=$(basename "${RELEASE_IMAGE_3}")
sha256sum ${RELEASE_IMAGE_FILE_3} > "${RELEASE_IMAGE_FILE_3}.sha256"
RELEASE_IMAGE_FILE_4=$(basename "${RELEASE_IMAGE_4}")
sha256sum ${RELEASE_IMAGE_FILE_4} > "${RELEASE_IMAGE_FILE_4}.sha256"
RELEASE_IMAGE_FILE_5=$(basename "${RELEASE_IMAGE_5}")
sha256sum ${RELEASE_IMAGE_FILE_5} > "${RELEASE_IMAGE_FILE_5}.sha256"
RELEASE_IMAGE_FILE_6=$(basename "${RELEASE_IMAGE_6}")
sha256sum ${RELEASE_IMAGE_FILE_6} > "${RELEASE_IMAGE_FILE_6}.sha256"
RELEASE_IMAGE_FILE_7=$(basename "${RELEASE_IMAGE_7}")
sha256sum ${RELEASE_IMAGE_FILE_7} > "${RELEASE_IMAGE_FILE_7}.sha256"
cd -

# copy in device independent stuff
cp SOURCE.md "$RELEASE_DIR"
cp NEWS "$RELEASE_DIR"
cp LICENSE* "$RELEASE_DIR"
cp external_install_bottom.sh external_install_top.sh skulls.sh "$RELEASE_DIR"
cp -a util "$RELEASE_DIR"

# copy in x230 stuff
cp x230/README.md \
	"$RELEASE_DIR/README_X230.md"

# copy in x230t stuff
cp x230t/README.md \
	"$RELEASE_DIR/README_X230T.md"

# copy in t430 stuff
cp t430/README.md \
	"$RELEASE_DIR/README_T430.md"

# copy in t440p stuff
cp t440p/README.md \
	"$RELEASE_DIR/README_T440P.md"

# copy in t530 stuff
cp t530/README.md \
	"$RELEASE_DIR/README_T530.md"

tar -cJf "$RELEASE_DIR".tar.xz "$RELEASE_DIR"

rm -rf "$RELEASE_DIR"

git commit -a -m "release skulls ${version}"
git tag -s "${version}" -m "skulls ${version}"

sha256sum "$RELEASE_DIR".tar.xz > "$RELEASE_DIR".tar.xz.sha256
sha512sum "$RELEASE_DIR".tar.xz > "$RELEASE_DIR".tar.xz.sha512
gpg -b -a "$RELEASE_DIR".tar.xz
