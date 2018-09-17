#!/usr/bin/env bash
# shellcheck disable=SC2128
SOURCED=false && [ "$0" = "$BASH_SOURCE" ] || SOURCED=true

# arguments
INPUT_FILE=''
DATE=''

# options
output_compression=''
debug=false
input_ext=''
dry_run=false
output_dir='.'

eval "$(docopts -V - -h - : "$@" <<EOF
Usage: merge_snapshots.sh [options] INPUT_FILE DATE

Arguments:
  DATE                            Date to merge.
  INPUT_FILE                      Input file with list of files to merge.

Options:
  -c {gzip,bz2,7z,None}, --output-compression {gzip,bz2,7z,None}
                                  Output compression format [default: gzip].
  -d, --debug                     Enable debugging output.
  -e, --input-ext INPUT_EXT       Input extensions [default: .gz].
  -n, --dry-run                   Do not output any file.
  -o, --output-dir OUTPUT_DIR     Output directory [default: .].
  -h, --help                      Show this help message and exits.
  --version                       Print version and copyright information.
----
merge_snapshots.sh 0.2
copyright (c) 2018 Cristian Consonni
MIT License
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.
EOF
)"

if ! $SOURCED; then
  set -euo pipefail
  IFS=$'\n\t'
fi

tempdir=$(mktemp -d -t tmp.merge_snapshots.XXXXXXXXXX)
function finish {
  rm -rf "$tempdir"
}
trap finish EXIT

#################### utils
if $debug; then
  function echodebug() {
    (>&2 echo -en "[$(date '+%F_%k:%M:%S')][debug]\\t")
    (>&2 echo "$@" 1>&2)
  }
else
  function echodebug() { true; }
fi
####################

compression_ext=''
case "$output_compression" in
  "gzip")
    compression_command='gzip'
    compression_ext='.gz'
    ;;
  "bz2")
    compression_command='bz2'
    compression_ext='.bz2'
    ;;
  "7z")
    compression_command='7z a -si'
    compression_ext='.7z'
    ;;
  *)
    unset compression_command
    ;;
esac
echodebug "Arguments:"
echodebug "  * DATE: $DATE"
echodebug "  * INPUT_FILE: $INPUT_FILE"
echodebug

echodebug "Options:"
echodebug "  * output_compression (-c): $output_compression"
echodebug "  * debug (-d): $debug"
echodebug "  * input_ext (-e): $input_ext"
echodebug "  * dry run (-n): $dry_run"
echodebug "  * output directory (-o): $output_dir"
echodebug
echodebug "tempdir: $tempdir"
echodebug

if [[ ! -z "${compression_command+x}" ]]; then
  echodebug "  * output compression (-o): $output_compression"
  echodebug "    -> compression command: $compression_command"
else
  echodebug "  * output compression (-o): None"
fi

echodebug "Creating output dir: ${output_dir}"
if ! $dry_run; then
  mkdir -p "${output_dir}"
else
  echodebug "Skipping because -n (dry run) option given."
fi

declare -a filestocat
filestocat=()

if $debug; then
  set -x
fi
mapfile -t filestocat < <( grep -E "$DATE\\.csv$input_ext.?$" \
                             "$INPUT_FILE" )
set +x

if [ "${#filestocat[@]}" -gt 0 ]; then
  echo "$DATE -> snapshot.$DATE.csv$compression_ext"

  snapshot_tmpfile="$tempdir/snapshot.$DATE.tmp.txt"
  snapshot_header="$tempdir/snapshot.$DATE.header.txt"
  echodebug "snapshot_tmpfile: $snapshot_tmpfile"
  echodebug "snapshot_header: $snapshot_header"

  snapshot_file="snapshot.$DATE.csv$compression_ext"
  echodebug "snapshot_file: $snapshot_file"

  # save header in a temporary file
  # This is the correct way to do it when set -o pipefail is set:
  #   https://stackoverflow.com/a/41516237/2377454
  head -n1 < <(zcat "${filestocat[0]}") > "$snapshot_header"

  touch "$snapshot_tmpfile"
  for afile in "${filestocat[@]}"; do
    echodebug "Processing file: $afile"
    tail -n+2 < <(zcat "$afile") >> "$snapshot_tmpfile"
  done
  cat "$snapshot_header" "$snapshot_tmpfile" | sponge "$snapshot_tmpfile"

  echodebug "Finalize file $output_dir/$snapshot_file"

  if ! $dry_run; then
    sort -n "$snapshot_tmpfile" | \
      $output_compression >> "$output_dir/$snapshot_file"
  fi

else
  (>&2 echo 'No files to cat, exiting.')
  exit 2
fi

exit 0
