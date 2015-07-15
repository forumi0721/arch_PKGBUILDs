#!/usr/bin/env bash

echo_white() {
	echo -e "\e[01;0m${1}\e[0m${2}"
}

echo_gray() {
	echo -e "\e[01;30m${1}\e[0m${2}"
}

echo_red() {
	echo -e "\e[01;31m${1}\e[0m${2}"
}

echo_green() {
	echo -e "\e[01;32m${1}\e[0m${2}"
}

echo_yellow() {
	echo -e "\e[01;33m${1}\e[0m${2}"
}

echo_blue() {
	echo -e "\e[01;34m${1}\e[0m${2}"
}

echo_violet() {
	echo -e "\e[01;35m${1}\e[0m ${2}"
}

echo_cyan() {
	echo -e "\e[01;36m${1}\e[0m${2}"
}


#Validation
if [ -z "$(which rsync 2> /dev/null)" ]; then
	echo_red "command not found : rsync"
	exit 1
fi


#Main
LOCAL_REPO="stonecold-repo"
RSYNC_ID=forumi0721
RSYNC_SVR=192.168.0.21
RSYNC_PATH=/mnt/VOL1/nas_htdocs/arch/StoneCold

echo_green "==> " "Start - rsync..."

rsync -avrh --delete --progress ${LOCAL_REPO}/* ${RSYNC_ID}@${RSYNC_SVR}:${RSYNC_PATH}

echo_green "==> " "Done."
echo

exit ${?}

