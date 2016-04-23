#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

readarray dates < "$1"

OLD_PWD=$PWD
OUTPUT_DIR="/tmp/cristian.consonni/shared/output"
GRAPHS_DIR="$OUTPUT_DIR/clustersci-graphsnapshot-linkextractor-output/graphs"

for dd in "${dates[@]}"; do
    echo -n "$dd"

    # trim newline
    dd=$(echo $dd | tr -d '\n')

    graph_tar_file="graph.${dd}.csv.tar.gz"

    mkdir "${dd}"
    cd "${dd}"

    cp "$GRAPHS_DIR/$graph_tar_file" "$graph_tar_file"
    tar xvzf "$graph_tar_file"
    rm "$graph_tar_file"

    ls -1 | grep ".features.${dd}." > input-files
    /tmp/wikigraph/merge_linkextractions.sh \
        --output-compression gzip \
        --input input-files "${dd}"

    cp "link_snapshot.${dd}.csv.gz" "$OUTPUT_DIR/link-snapshots/"

    cd $OLD_PWD
    rm -r "${dd}"

done
