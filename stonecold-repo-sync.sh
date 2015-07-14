#!/usr/bin/env bash

echo_red() {
	echo -e "\e[0;31m${1}\e[0m"
}

echo_green() {
	echo -e "\e[0;32m${1}\e[0m"
}

echo_blue() {
	echo -e "\e[0;34m${1}\e[0m"
}

if [ -z "$(which rsync)" ]; then
	echo_red "Cannot found rsync"
	exit 0
fi

LOCAL_REPO="stonecold-repo"
RSYNC_ID=forumi0721
RSYNC_SVR=192.168.0.21
RSYNC_PATH=/mnt/VOL1/nas_htdocs/arch/StoneCold

echo_green "rsync start..."
rsync -avrh --delete --progress ${LOCAL_REPO}/* ${RSYNC_ID}@${RSYNC_SVR}:${RSYNC_PATH}
echo

