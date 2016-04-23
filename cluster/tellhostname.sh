#!/bin/bash
set -x

CLUSTER_USER='cristian.consonni'

echo "tellhostname.sh"
mkdir -p /tmp/$CLUSTER_USER

SHARED_PATH="/tmp/$CLUSTER_USER/shared"

[ ! -L "$SHARED_PATH" -a -d "$SHARED_PATH" ] && rm -r "$SHARED_PATH"

mkdir -p "$SHARED_PATH"

ln -sf /mnt/voldisi/cconsonni/cluster/ "$SHARED_PATH/cluster"
ln -sf /mnt/voldisi/datasets/dumps/en/20150901/ "$SHARED_PATH/input"
ln -sf /mnt/voldisi/cconsonni/wikilink-output/ "$SHARED_PATH/output"

BASE_DIR="$SHARED_PATH/cluster/tellhostname"

mkdir -p "$BASE_DIR"

cd "$BASE_DIR"

export PATH="$SHARED_PATH/cluster/python3.5/bin:$PATH"

source "$SHARED_PATH/cluster/wikidump-cluster/wdump/bin/activate"

hostname >> "$BASE_DIR/host.$(hostname)"
python --version >> "$BASE_DIR/host.$(hostname).python"
pip freeze >> "$BASE_DIR/host.$(hostname).freeze"
sleep 5m
exit
