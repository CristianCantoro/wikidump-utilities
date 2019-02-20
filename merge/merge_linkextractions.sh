#!/usr/bin/env bash
# shellcheck disable=SC2128
SOURCED=false && [ "$0" = "$BASH_SOURCE" ] || SOURCED=true

if ! $SOURCED; then
  set -euo pipefail
  IFS=$'\n\t'
fi

scratch=$(mktemp -d -t tmp.merge_linkextractions.XXXXXXXXXX)
function finish {
  rm -rf "$scratch"
}
trap finish EXIT

output_compression=false
verbose=false
input=''
lang='en'

eval "$(docopts -V - -h - : "$@" <<EOF
Usage: merge_linkextractions.sh [options] --input INPUT_FILE --lang LANG DATE

      DATE                                  Date to merge
      --input INPUT_FILE                    Input file with list.
      --lang LANG                           Language to process,i.e. prefix
                                            of the output filename [default: en].
      --dry-run                             Do not output any file.
      --output-compression {gzip,7z,None}   Output compression format.
                                            (default: None).
      -v, --verbose                         Verbose output.
      -h, --help                            Show this help message and exits.
      --version                             Print version and copyright.
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
  echo "lang: $lang"

  if [[ -n "$compression_command" ]]; then
    echo -n "output compression: $output_compression"
    echo    " - compression commnand: $compression_command"
  else
    echo "ouput compression: None"
  fi

  echo "temporary directory: $scratch"
fi

outfile_name="${lang}link_snapshot.$DATE.csv.gz"
tmpfile="${scratch}/${lang}link_snapshot.$DATE.csv.tmp"

echo "$DATE -> $outfile_name"

firstline=true
grep ".$DATE.csv.gz" "$input" | while read -r link_file; do
  if $firstline; then
    zcat "$link_file" | head -n1 >> "$tmpfile" || true
    firstline=false
  fi

  if $verbose; then
    echo "zcat $link_file | tail -n+2 >> $tmpfile"
  fi
  zcat "$link_file" | tail -n+2 >> "$tmpfile"
done

# How to obtain the number of CPUs/cores in Linux from the command line?
# https://stackoverflow.com/q/6481005/2377454
NPROCS="$(grep -c '^processor' /proc/cpuinfo)"
_totmemkb="$(cat /proc/meminfo | grep MemTotal | awk '{print $2}')"
TOTMEMGB=$((_totmemkb/(1024*1024)))

set -x
# Parallel sort
# https://superuser.com/q/938558/469670
sort \
  --field-separator=',' \
  --numeric-sort \
  --key=1 \
  --parallel=$((NPROC-1)) \
  --buffer-size=$((TOTMEMGB/NPROCS)) \
    "$tmpfile" | \
  $output_compression > "$outfile_name"
set +x

exit 0
