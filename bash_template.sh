#!/bin/bash
SCRIPT_HOME=""
PROGNAME=$(basename $0)
VERSION=1.0
SCRIPTTIME=$(date +"%F %T")
LOGFILE="${SCRIPT_HOME}/${PROGNAME}.log"
OPTS=$(getopt -o o:c:rtv --long open:,close:,reload,test,version)





loggit () {
	echo $@ >> ${LOGFILE}
}
argumentcheck () {
	case $1 in
		-a | --audit )
			fireaudit
			;;
		-o | --open )
			if [ -n "$2" ]; then
				#moves to the field after the argument
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