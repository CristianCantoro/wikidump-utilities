#!/usr/bin/env bash
# shellcheck disable=SC2128
SOURCED=false && [ "$0" = "$BASH_SOURCE" ] || SOURCED=true

# arguments
declare -a FILE
OUTPUT_DIR=''
# options
debug=false
input_ext=''
dry_run=false
output_compression=''
verbose=false

eval "$(docopts -V - -h - : "$@" <<EOF
Usage: tar_snapshots.sh [options] ( -o OUTPUT_DIR | --output-dir OUTPUT_DIR )
                                  FILE [FILE ...]

Take all files of the form
  <output_dir>/<file>.*.<date>.csv.gz
to produce a tar
  <file>.features.csv.tar.gz

Note that the idea is to tar all the files pertaining to a given input.

Arguments:
  FILE                            File to parse.
  -o, --output-dir OUTPUT_DIR     Output directory.

Options:
  -c, {gzip,bz2,7z,None}, --output-compression {gzip,bz2,7z,None}
                                  Output compression format [default: gzip].
  -d, --debug                     Enable debugging output.
  -i, --input-ext INPUT_EXT       Input extensions [default: .gz].
  -n, --dry-run                   Do not output any file.
  -v, --verbose                   Generate verbose output.
  -h, --help                      Show this help message and exits.
  --version                       Print version and copyright information.

Example:
  ./tar_snapshots.sh -o output enwiki-20180301-pages-meta-history1.xml-p10p2115.7z
----
tar_snapshots.sh 0.2
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

echodebug "Arguments:"
echodebug "  * FILE: $FILE"
echodebug "  * output dir (-o): $OUTPUT_DIR"
echodebug

echodebug "Options:"
echodebug "  * debug (-d): $debug"
echodebug "  * input_ext (-i): $input_ext"
echodebug "  * dry run (-n): $dry_run"
echodebug "  * verbose (-v): $verbose"
echodebug

compression_flag=''
compression_ext=''
case "$output_compression" in
  "gzip")
    compression_flag='--gzip'
    compression_ext='.gz'
    ;;
  "bz2")
    compression_flag='--bz2'
    compression_ext='.bz2'
    ;;
  "7z")
    compression_flag='7z'
    compression_ext='.7z'
    ;;
  *)
    unset compression_flag
    ;;
esac
echodebug "compression_flag: ${compression_flag:-None}"

for inputfile in "${FILE[@]}"; do
  count="$( find "$OUTPUT_DIR" \
                -type f \
                -name "*.csv$input_ext" \
                -printf '.' | wc -c )"
  echodebug "count: $count"

  if [ "$count" -gt 0 ]; then
    filename=$(basename "$inputfile")

    verbose_flag=''
    if $verbose; then
      # if verbose, tar flags are set to 'vczf'
      verbose_flag='-v'
    fi

    rgx="$OUTPUT_DIR/"
    rgx+="$filename\\.features\\.xml\\.(gz|bz2|7z)"
    rgx+="\\.features\\.[0-9]{4}-[0-9]{2}-[0-9]{2}\\.csv$input_ext"
    # Reading output of a command into an array in Bash
    # https://stackoverflow.com/q/11426529/2377454
    mapfile -t filestotar < <( find "$OUTPUT_DIR" \
                                    -type f \
                                    -regextype posix-extended \
                                    -regex "$rgx" )

    output_tarname="$filename.features.csv.tar$compression_ext"
    echodebug "output_tarname: $output_tarname"
    if ! $dry_run; then
      if [ "${compression_flag:-}" == "7z" ]; then
        set -x
        tar --create --file - "${filestotar[@]}" | \
          7z a -si "$output_tarname"
        set +x
      else
        set -x
        tar ${verbose_flag:-} ${compression_flag:-} \
            --create \
            --file "$output_tarname" \
              "${filestotar[@]}"
        set +x
      fi
    fi
  fi
done

exit 0
