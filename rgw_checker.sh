#!/bin/bash
SCRIPT_HOME="/root"
PROGNAME=$(basename $0)
VERSION=1.0
SCRIPTTIME=$(date +"%F %T")
LOGFILE="${SCRIPT_HOME}/${PROGNAME}.log"
SERVICENAME="ceph-radosgw@rgw.$(hostname -s).service"

loggit () {
	echo "${SCRIPTTIME} $@" >> ${LOGFILE}
}

rgw_restart_function () {
	if ! systemctl is-active ${SERVICENAME}; then
		systemctl reset-failed ${SERVICENAME}
		systemctl restart ${SERVICENAME}
		loggit "restarted rados gateway."
	fi
	if systemctl is-active ${SERVICENAME}; then
		loggit "verified the rgw is running."
	fi
}
rgw_restart_function