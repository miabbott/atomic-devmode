#!/bin/bash
set -euo pipefail

main() {
	if [ $# -eq 0 ]; then
		rm -f /run/atomic-devmode-cockpit.rc
		tmux split-window -d -v -t devmode:main.0 "$0 bottom"
		exec $0 top
	else
		${1}_pane
	fi
}

top_pane() {

	ip=$(get_external_ip)

	cat << EOF
Welcome to Atomic Developer Mode!

Password for root:  $(cat /run/atomic-devmode-root)
IP address:         $ip
EOF

	echo -n "Cockpit console:    < downloading... > "

	while [ ! -f /run/atomic-devmode-cockpit.rc ]; do
		sleep 1
	done

	rc=$(cat /run/atomic-devmode-cockpit.rc)
	if [ "$rc" != 0 ]; then
		echo
		echo "ERROR: Could not start cockpit container."
	else
		echo -e "\rCockpit console:    https://$ip:9090/"
	fi

	echo
	exec bash
}

get_external_ip() {

	# get IP of docker bridge if present and running
	if [ -e /sys/class/net/docker0 ] && \
	   [ "$(cat /sys/class/net/docker0/carrier)" == 1 ]; then
		docker_ip=$(ip -f inet -o addr show docker0 | cut -d\  -f 7 | cut -d/ -f 1)
	fi

	# go through all IPs that are not docker and just pick the first one
	external_ip="N/A"
	for ip in $(hostname -I); do
		if [ "$ip" != "$docker_ip" ]; then
			external_ip=$ip
			break
		fi
	done

	echo $external_ip
}

bottom_pane() {
	rc=0
	atomic run cockpit/ws || rc=$?
	echo $rc > /run/atomic-devmode-cockpit.rc
	journalctl -f
	exec bash
}

main "$@"
