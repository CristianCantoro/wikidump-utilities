#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

readarray dates < "$1"

for dd in "${dates[@]}"; do
    echo -n "$dd"

    # trim newline
    dd=$(echo $dd | tr -d '\n')

    # counting files
    # find . -maxdepth 1 -regex ".*${dd}.*"
    ls -1 *${dd}* | wc -l || true

    tar cvzf "graphs/graph.$dd.csv.tar.gz" *${dd}*
    # rm *${dd}*
done
