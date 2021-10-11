#!/bin/bash
source "util/functions.sh"

warn_not_root

have_config=0

usage()
{
	echo "Skulls for the T440P"
	echo "  Run this script to rebuild a released image"
	echo ""
	echo "Usage: $0 [-c <config_file>]"
	echo ""
	echo " -c <config_file>        to use for flashrom"
}

args=$(getopt -o c:h -- "$@")
if [ $? -ne 0 ] ; then
	usage
	exit 1
fi

eval set -- "$args"
while [ $# -gt 0 ]
do
	case "$1" in
	-c)
		CONFIGFILE=$2
		have_config=1
		shift
		;;
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

if [ ! "$have_config" -gt 0 ] ; then
	configs_available=$(ls -1 | grep config || true)
	if [ -z "${configs_available}" ] ; then
		echo "No config file found. Please add -c <file>"
		echo ""
		usage
		exit 1
	fi

	prompt="Please select a configuration to use for building or start with the -c option to use a different one:"
	options=( $(find -maxdepth 1 -name "*config*" -print0 | xargs -0) )

	PS3="$prompt "
	select CONFIGFILE in "${options[@]}" "Quit" ; do
		if (( REPLY == 1 + ${#options[@]} )) ; then
			exit

		elif (( REPLY > 0 && REPLY <= ${#options[@]} )) ; then
			break

		else
			echo "Invalid option. Try another one."
		fi
	done
fi

rm -f defconfig-*
CONFIGFILE_READY=$(echo $CONFIGFILE | cut -d'-' -f2-)
cp $CONFIGFILE $CONFIGFILE_READY

cd ..
./build.sh --clean-slate --commit $(ls -1 t440p/defconfig-* |  cut -d'-' -f2-) t440p
rm -f t440p/defconfig-*
