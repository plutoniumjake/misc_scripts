#!/bin/bash
#jvandeventer
#allows migration tracker to open and close port 80 and 443 on the yarrrdstick server.
#Error codes:
#	10: The script does not have adequate permissions to open the firewall. Check the sudoers and the user running the script.
#	11: The script does not have adequate permissions to close the firewall. Check the sudoers and the user running the script.
#	12: The script does not have adequate permissions to reload the firewall. Check the sudoers and the user running the script.
#	13: An invalid IP was given. Check the IP's that were passed to the script.
#	14: Failed to update the test file. Check the sudoers and the user running the script.
#	15: No IP was given.
#	16: No flags were passed when the script was called.
#	17: An invalid flag was passed.
PROGNAME=$(basename $0)
VERSION=1.0
SCRIPTTIME=$(date +"%F %T")
LOGFILE="/var/log/firescript.log"
check_all_ips () {
	for ip_address in ${ALL_IPS}; do
		if ! ipcalc -cs ${ip_address}; then
			loggit "${SCRIPTTIME} ERR13: ${ip_address} invalid."
			exit 13
		fi
	done
}
fireopen () {
	for IPADDRESS in ${ALL_IPS}; do
		OPEN80="/bin/firewall-cmd -q --perm --direct --add-rule ipv4 filter OUTPUT 0 -p tcp -m tcp -d ${IPADDRESS} --dport=80 -j ACCEPT"
		OPEN443="/bin/firewall-cmd -q --perm --direct --add-rule ipv4 filter OUTPUT 0 -p tcp -m tcp -d ${IPADDRESS} --dport=443 -j ACCEPT"
		if sudo -l ${OPEN80} > /dev/null && sudo -l ${OPEN443} > /dev/null; then
			sudo ${OPEN80}
			sudo ${OPEN443}
			loggit "${SCRIPTTIME} opened firewall for ${IPADDRESS}." 
		else
			loggit "${SCRIPTTIME} ERR10: failed to open firewall for ${IPADDRESS}."
			exit 10
		fi
	done
	fw_reload
}
fireshut () {
	for IPADDRESS in ${ALL_IPS}; do
		CLOSE80="/bin/firewall-cmd -q --perm --direct --remove-rule ipv4 filter OUTPUT 0 -p tcp -m tcp -d ${IPADDRESS} --dport=80 -j ACCEPT"
		CLOSE443="/bin/firewall-cmd -q --perm --direct --remove-rule ipv4 filter OUTPUT 0 -p tcp -m tcp -d ${IPADDRESS} --dport=443 -j ACCEPT"
		if sudo -l ${CLOSE80} > /dev/null && sudo -l ${CLOSE443} > /dev/null; then
			sudo ${CLOSE80}
			sudo ${CLOSE443}
			loggit "${SCRIPTTIME} closed firewall for ${IPADDRESS}." 
		else
			loggit "${SCRIPTTIME} ERR11: failed to close firewall for ${IPADDRESS}." 
			exit 11
		fi
	done
	fw_reload
}
fw_reload () {
	if sudo -l /bin/firewall-cmd -q --reload > /dev/null; then
		sudo /bin/firewall-cmd -q --reload
	else
		exit 12
	fi
}
fireaudit () {
	IPREGEX="((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)"
	IPSTHATSTAY="67.43.3.84"
	sudo firewall-cmd --direct --get-all-rules | grep -Eo "${IPREGEX}" | grep -v "${IPSTHATSTAY}" | sort -u
	loggit "${SCRIPTTIME} firewall audit requested." 

}
test_me () {
	sudo -n /bin/touch /root/testfile  &>2 || exit 14
}
loggit () {
	echo $@ >> ${LOGFILE}
}
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