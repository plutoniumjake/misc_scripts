#!/bin/bash

get_user_input () {
	echo_default () {
		if [ ! -z "$1" ]; then echo "[$1]";
		fi
	}
	local failure_count=0
	# shellcheck disable=SC2034
	local question=$1
	local default=$2
	local check=$3
	local dest=$4
	while true ;do
		if [ $failure_count -ge 10 ]; then
			echo "Are you even trying?"
			failure_count=0
		fi
		# shellcheck disable=SC2086
		read -p "$1$( echo_default "$default" ) " input
		if [ -z "$input" ] ; then
			if [ ! -z "$default" ]; then
				input="$default"
			fi
		fi
		if $check "$input" ; then
			eval "$dest='$input'";
			break
		fi
		(( failure_count++ ))
	done
}

check_if_2 () {
	if [[ ${1} == 2 ]]; then
		echo "That looks like a 2."
	else
		echo "That's not a 2."
		return 1
	fi	
}

get_user_input "Please enter 2: " check_if_2 NUMBER_TWO 