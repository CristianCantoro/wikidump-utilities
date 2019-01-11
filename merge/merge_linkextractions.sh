#!/usr/bin/env bash
# shellcheck disable=SC2128
SOURCED=false && [ "$0" = "$BASH_SOURCE" ] || SOURCED=true

if ! $SOURCED; then
  set -euo pipefail
  IFS=$'\n\t'
fi

output_compression=false
verbose=false
input=''

eval "$(docopts -V - -h - : "$@" <<EOF
Usage: merge_linkextractions.sh [options] --input INPUT_FILE DATE

      DATE                                  Date to merge
      --input INPUT_FILE                    Input file with list
      --dry-run                             Do not output any file
      --output-compression {gzip,7z,None}   Output compression format
                                            (default: None).
      -v, --verbose                         Verbose output.
      -h, --help                            Show this help message and exits.
      --version                             Print version and copyright
                                            information.
----
merge_snapshots.sh 0.2.0
copyright (c) 2018 Cristian Consonni
MIT License
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.
EOF
)"

case "$output_compression" in
  "gzip")
      compression_command='gzip'
      ;;
  "7z")
      compression_command='7z a -si'
      ;;
  *)
      unset compression_commnad
      ;;
esac

if $verbose; then
  echo "date: $DATE"
  echo "input: $input"

  if [[ -n "$compression_command" ]]; then
    echo -n "output compression: $output_compression"
    echo    " - compression commnand: $compression_command"
  else
    echo "ouput compression: None"
  fi
fi

echo "$DATE -> link_snapshot.$DATE.csv.gz"
rm -f "link_snapshot.$DATE.csv.tmp"

firstline=true
grep ".$DATE.csv.gz" "$input" | while read -r link_file; do
  if $firstline; then
    zcat "$link_file" | head -n1 >> "link_snapshot.$DATE.csv.tmp" || true
    firstline=false
  fi

  if $verbose; then
    echo "zcat $link_file | tail -n+2 >> link_snapshot.$DATE.csv.tmp"
  fi
  zcat "$link_file" | tail -n+2 >> "link_snapshot.$DATE.csv.tmp"
done

sort -n -k1 "link_snapshot.$DATE.csv.tmp" | \
  $output_compression > "link_snapshot.$DATE.csv.gz"
rm "link_snapshot.$DATE.csv.tmp"

exit 0
