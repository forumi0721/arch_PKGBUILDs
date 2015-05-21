#!/bin/sh

if [ -z "$(which rsync)" ]; then
	echo "Cannot found rsync"
	exit 0
fi

LOCAL_REPO="stonecold-repo"
RSYNC_ID=forumi0721
RSYNC_SVR=192.168.0.21
RSYNC_PATH=/mnt/VOL1/nas_htdocs/arch/StoneCold

echo "rsync start..."
rsync -avrh --delete --progress ${LOCAL_REPO}/* ${RSYNC_ID}@${RSYNC_SVR}:${RSYNC_PATH}
echo "Done"
echo

