#!/usr/bin/env bash
# shellcheck disable=SC2128
SOURCED=false && [ "$0" = "$BASH_SOURCE" ] || SOURCED=true

if ! $SOURCED; then
  set -euo pipefail
  IFS=$'\n\t'
fi

readarray dates < "$1"

OLD_PWD=$PWD
OUTPUT_DIR="/tmp/cristian.consonni/shared/output"
GRAPHS_DIR="$OUTPUT_DIR/clustersci-graphsnapshot-linkextractor-output/graphs"

for dd in "${dates[@]}"; do
    echo -n "$dd"

    # trim newline
    dd="$(echo "$dd" | tr -d '\n')"

    graph_tar_file="graph.${dd}.csv.tar.gz"

    mkdir "${dd}"
    cd "${dd}"

    cp "$GRAPHS_DIR/$graph_tar_file" "$graph_tar_file"
    tar xvzf "$graph_tar_file"
    rm "$graph_tar_file"

    find . \
      -mindepth 1 \
      -maxdepth 1 \
      -type f \
      -name "*.features.${dd}.*" \
      -exec basename {} \; > input-files

    /tmp/wikigraph/merge_linkextractions.sh \
        --output-compression gzip \
        --input input-files "${dd}"

    cp "link_snapshot.${dd}.csv.gz" "$OUTPUT_DIR/link-snapshots/"

    cd "$OLD_PWD"
    rm -r "${dd}"

done

exit 0
