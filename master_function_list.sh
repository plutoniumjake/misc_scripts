#!/bin/bash

######
#These use default arguments to change the use of the function.
#echo_only_what_has_changed also uses a default value for a variable.
health_check () {
	echo_only_what_is_changed "Overall health" "${HEALTH_FILE}" "${HEALTH_CHECK}"
}
echo_only_what_is_changed () {
	local what_changed=$1
	local tracking_file=$2
	local check=$3
	touch "${tracking_file}"
	old_check=$(cat "${tracking_file}")
	if [ ! "${check}" = "${old_check}" ]; then
		echo "*ceph message*: ${what_changed} has changed state. 
		Current state: ${check:-N/A}" | /usr/local/bin/slacktee.sh -p
	fi	
	echo "${check}" > "${tracking_file}"
}
#User input functions.
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
######
#My favorite yes/no.
yesno () {
	while true; do
		read -rp "${*}? [y/n] " yn
		case $yn in
			yes|Yes|YES|y|Y)
				return 0  ;;
			no|No|n|N|NO)
				return 1  ;;
			*)
				echo "Please answer 'y' or 'n'."
		esac
	done
}
######
#Logging function
loggit () {
	echo "${SCRIPTTIME} ${LINENO} $*" >> ${LOGFILE}
}
######
#Say okay
say_okay () {
	echo "(enter to continue)"
	# shellcheck disable=SC2162
	read
}
######
#trap ctrl-c
ctrl_c () {
	echo "**CTRL-C** pressed.**"
	if yesno 'Continue'; then
		return 0
	else
		break
	fi
}
trap ctrl_c INT
######
#Strips https://
d () {
	R=""
	for A in $@ ; do
		T=$(echo $A | sed -r 's#^http(s)?://([^/]+)/?#\2#')
		R="$R $T"
	done
	/usr/bin/dig ANY +noall +answer $R
}
######
#Contains ip regex
fireaudit () {
	IPREGEX="((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)"
	IPSTHATSTAY="67.43.3.84"
	sudo firewall-cmd --direct --get-all-rules | grep -Eo "${IPREGEX}" | grep -v "${IPSTHATSTAY}" | sort -u
	loggit "${SCRIPTTIME} firewall audit requested." 

}
######
#Taking arguments from the command line
OPTS=$(getopt -o o:c:rtv --long open:,close:,reload,test,version)
argumentcheck () {
	case $1 in
		-a | --audit )
			fireaudit
			;;
		-o | --open )
			if [ -n "$2" ]; then
				shift
				ALL_IPS=$@
				check_all_ips
				fireopen
			else
				exit 15
			fi
			;;
		-c | --close )
			if [ -n "$2" ]; then
				shift
				ALL_IPS=$@
				check_all_ips
				fireshut
			else
				exit 15
			fi
			shift
			;;
		-r | --reload )
			fw_reload
			;;
		-t | --test )
			test_me
			;;
		-v | --version )
			echo "${VERSION}"
			;;
		* )	
			loggit "${SCRIPTTIME} ERR17: invalid flag given."
			exit 17
			;;
	esac
}
if [[ x == x"$@" ]]; then
	loggit "${SCRIPTTIME} ERR16: script called with no flags given."
	exit 16
else
	argumentcheck "$@"
fi
######
#Stripping white space
chomp ()
{
    sed 's/^[ \t]*//;s/[ \t]*$//'
}
######
#interesting parameter expansion
server_dc=$(printf "${input_gb_ip:3:1}") # gets 1 char value in #3 position from string (starting from 0)
bm_dc=$(printf "${input_gb_bmnode:0:1}") # gets 1 char value in #0 position from input_gb_bmnode
######
#Printing in colors.
ec () {
	ecolor=${!1}
	shift
	echo -e "${ecolor}""${*}""${nocolor}"
}
#Printing in colors with no new line.
ecn () {
	ecolor=${!1}
	shift
	echo -ne "${ecolor}""${*}""${nocolor}"
}
######
#make sure this is being run in screen
screen_check () {
	if [[ ! "${STY}" ]]; then
		ec lightRed "Warning! You are not in a screen session!"
		echo -n "Please start a screen session, then re-run the script. (enter to continue)"
		read
		exit 1
	fi
}
######
#Arrays (A is an associative array)
declare -A DEGRADED_MDS
declare -a MD_ARRAY
declare -a LIVE_DEVICE_ARRAY
identify_md_devices () {
	MD_ARRAY=(${MD_DEVICES})
	mdcount=0
	for md_dev in ${MD_ARRAY[@]}; do
		mdadm -D /dev/${md_dev} | grep -q degraded 
		DEGRADE_CHECK=$?
		if [ "${DEGRADE_CHECK}" == 0 ]; then
			part=$(mdadm -D /dev/${MD_ARRAY[mdcount]} |grep "active sync" | awk '{print $7}')
			DEGRADED_MDS["${md_dev}"]=${part}
		fi
		mdcount=$(( $mdcount + 1 ))
	done
}
identify_physical_devices () {
	LIVE_DEVICE_ARRAY=($(printf "%s\n" "${DEGRADED_MDS[@]%[0-9]}" | sort -u))
	for disk in ${LIVE_DEVICE_ARRAY[@]}; do
		size=$(lsblk -dn -o size ${disk})
		echo
		echo "${disk} is an active disk. the size is ${size}."
		echo "The md devices it houses are:"
		for mapped_dev in ${!DEGRADED_MDS[@]}; do
			echo "${mapped_dev} = ${DEGRADED_MDS[$mapped_dev]}"
		done
		echo "-----"
		if yesno "Is $disk the correct active disk"; then
			OLD_DISK=${disk}
			OLD_DISK_SIZE=${size%[A-Za-z]}
			break
		fi
	done
	if [ -z "${OLD_DISK}" ]; then
		DENY "There is no active disk."
		script_death
	fi
}
######
#
