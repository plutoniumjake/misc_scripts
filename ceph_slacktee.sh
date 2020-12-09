#!/bin/bash
#jvandeventer
#Current checks:
#state (cluster health)
#near-full osds
#down osds
#blocked operations
#backfill monitoring
#noout monitoring
#################
#GLOBAL VARIABLES
CEPH_DETAIL_TEMP=$(mktemp)
ceph health detail > ${CEPH_DETAIL_TEMP}
HEALTH_FILE="/tmp/slacktee_health"
HEALTH_CHECK=$(cat "${CEPH_DETAIL_TEMP}" | grep HEALTH | awk '{print $1}')
OSD_DROP_FILE="/tmp/slacktee_osd_drop"
OSD_DROP_CHECK=$(cat ${CEPH_DETAIL_TEMP} | grep -E "^osd.* is down")
OSD_DOWN_FILE="/tmp/slacktee_osd_down"
OSD_DOWN_CHECK=$(ceph osd tree | grep down)
OSD_NEAR_FULL_FILE="/tmp/slacktee_osd_near_full"
OSD_NEAR_FULL_CHECK=$(cat ${CEPH_DETAIL_TEMP} | grep -E "^osd.* is near")
OSD_BLOCKED_CHECK=$(cat ${CEPH_DETAIL_TEMP} | awk '/ops are blocked/ && /sec on osd/ { print; }')
NOOUT_FILE="/tmp/slacktee_noout"
NOOUT_CHECK=$(cat ${CEPH_DETAIL_TEMP} | grep -E "^noout flag\(s\) set")
BACKFILL_FILE="/tmp/slacktee_backfill"
BACKFILL_CHECK=$(cat ${CEPH_DETAIL_TEMP} | egrep ^recovery)
##########
#FUNCTIONS
health_check () {
	echo_only_what_is_changed "Overall health" "${HEALTH_FILE}" "${HEALTH_CHECK}"
}
osd_drop_check_function () {
	echo_only_what_is_changed "OSD drop status" "${OSD_DROP_FILE}" "${OSD_DROP_CHECK}"
}
osd_down_check_function () {
	touch "${OSD_DOWN_FILE}"
	OLD_OSD_DOWN_CHECK=$(cat "${OSD_DOWN_FILE}")
	if [[ ! -z "${OSD_DOWN_CHECK}" ]] && [ ! "${OSD_DOWN_CHECK}" = "${OLD_OSD_DOWN_CHECK}" ]; then
		IFS=" " read -ra TREEARRAY <<< $( echo "${OSD_DOWN_CHECK}" )
		echo "*ceph message:* ${TREEARRAY[2]} is still ${TREEARRAY[3]}. reweight value is ${TREEARRAY[4]}." | /usr/local/bin/slacktee.sh -p
	fi
	echo "${OSD_DOWN_CHECK}" > "${OSD_DOWN_FILE}"
}
osd_near_full_check_function () {
	echo_only_what_is_changed "OSD near full status" "${OSD_NEAR_FULL_FILE}" "${OSD_NEAR_FULL_CHECK}"
}
osd_blocked_check_function () {
	SLOW_TIME=$(date +%c)
	if [ ! -z "${OSD_BLOCKED_CHECK}" ]; then
		echo "${SLOW_TIME} - ${OSD_BLOCKED_CHECK}" | /usr/local/bin/slacktee.sh -p
	fi
}
noout_check () {
	echo_only_what_is_changed "No out status" "${NOOUT_FILE}" "${NOOUT_CHECK}"
}
backfill_check () {
	PG_NUM=$(ceph -s | grep -E "(recovery [0-9]|pgs recovery)")
	if [ -s "${BACKFILL_FILE}" ]; then
		echo_only_what_is_changed "Backfill status" "${BACKFILL_FILE}" "${PG_NUM}"
	fi
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
######
#LOGIC
health_check
osd_drop_check_function
if [[ "${HEALTH_CHECK}" = "HEALTH_OK" ]]; then
	osd_down_check_function
fi
osd_near_full_check_function
osd_blocked_check_function
noout_check
backfill_check