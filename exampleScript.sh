#!/bin/bash
set -e
set -o pipefail

function calltracer () {
	echo 'Last file/last line:'
	caller
}
trap 'calltracer' ERR

function help () {
	echo "Possible options:"
	echo "	--notype"
	echo "	--only_int=INT                                     default value: 51"
	echo "	--onlyfloat=FLOAT                                  default value: 3.14159"
	echo "	--help                                             this help"
	echo "	--debug                                            Enables debug mode (set -x)"
	exit $1
}
export notype
export only_int=51
export onlyfloat=3.14159
for i in $@; do
	case $i in
		--notype=*)
			notype="${i#*=}"
			shift
			;;
		--only_int=*)
			only_int="${i#*=}"
			re='^[+-]?[0-9]+$'
			if ! [[ $only_int =~ $re ]] ; then
				echo "error: Not a INT: $i" >&2
				help 1
			fi
			shift
			;;
		--onlyfloat=*)
			onlyfloat="${i#*=}"
			re='^[+-]?[0-9]+([.][0-9]+)?$'
			if ! [[ $onlyfloat =~ $re ]] ; then
				echo "error: Not a FLOAT: $i" >&2
				help 1
			fi
			shift
			;;
		-h|--help)
			help 0
			;;
		--debug)
			set -x
			;;
		*)
			echo "Unknown parameter $i" >&2
			help 1
			;;
	esac
done
