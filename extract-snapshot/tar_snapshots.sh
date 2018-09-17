#!/usr/bin/env bash
# shellcheck disable=SC2128
SOURCED=false && [ "$0" = "$BASH_SOURCE" ] || SOURCED=true

# arguments
declare -a FILE
INPUT_DIR=''

# options
debug=false
dry_run=false
input_ext=''
output_compression=''
output_dir='.'

eval "$(docopts -V - -h - : "$@" <<EOF
Usage: tar_snapshots.sh [options] INPUT_DIR FILE [FILE ...]

Take all files of the form
  <output_dir>/<file>.*.<date>.csv.gz
to produce a tar
  <file>.features.csv.tar.gz

Note that the idea is to tar all the files pertaining to a given input.

Arguments:
  FILE                            File to parse.
  INPUT_DIR                       Input directory with the files produced by
                                  graphsnapshot's extract-snapshoṫ.

Options:
  -c {gzip,bz2,7z,None}, --output-compression {gzip,bz2,7z,None}
                                  Output compression format [default: gzip].
  -d, --debug                     Enable debugging output.
  -e, --input-ext INPUT_EXT       Input extensions [default: .gz].
  -n, --dry-run                   Do not output any file.
  -o, --output-dir OUTPUT_DIR     Output directory [default: .].
  -h, --help                      Show this help message and exits.
  --version                       Print version and copyright information.

Example:
  ./tar_snapshots.sh -o tars
        output
        enwiki-20180301-pages-meta-history1.xml-p10p2115.7z
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

#################### info
echodebug "Arguments:"
echodebug "  * FILE: $FILE"
echodebug "  * INPUT_DIR: $INPUT_DIR"
echodebug

echodebug "Options:"
echodebug "  * output_compression (-c): $output_compression"
echodebug "    -A compression_flag: ${compression_flag:-None}"
echodebug "  * debug (-d): $debug"
echodebug "  * input_ext (-e): $input_ext"
echodebug "  * output_dir (-o): $output_dir"
echodebug "  * dry run (-n): $dry_run"
echodebug
#################### end: info

echodebug "Creating output dir: ${output_dir}"
if ! $dry_run; then
  mkdir -p ${output_dir}
else
  echodebug "skipping because -n (dry run) option given."
fi

for inputfile in "${FILE[@]}"; do
  filename=$(basename "$inputfile")
  dirname=$(dirname "$inputfile")

  echodebug "dirname: $dirname"
  echodebug "filename: $filename"

  count="$( find "$INPUT_DIR" \
                -type f \
                -name "$filename*.csv$input_ext" \
                -printf '.' | wc -c )"
  echodebug "count: $count"

  if [ "$count" -gt 0 ]; then
    verbose_flag=''
    if $debug; then
      # if verbose, tar flags are set to 'vczf'
      verbose_flag='-v'
    fi

    rgx="$INPUT_DIR/"
    rgx+="\\./(.*/)?$filename\\.features\\.xml\\.(gz|bz2|7z)"
    rgx+="\\.features\\.[0-9]{4}-[0-9]{2}-[0-9]{2}\\.csv$input_ext"
    # Reading output of a command into an array in Bash
    # https://stackoverflow.com/q/11426529/2377454
    mapfile -t filestotar < <( find "$INPUT_DIR" \
                                    -type f \
                                    -regextype posix-extended \
                                    -regex "$rgx" )

    output_tarname="$filename.features.csv.tar$compression_ext"
    echodebug "tar output: $output_dir/$output_tarname"

    if ! $dry_run; then
      if [ "${compression_flag:-}" == "7z" ]; then
        set -x
        tar --create \
            -C "$dirname" \
            --file - \
              "${filestotar[@]}" | \
          7z a -si "$output_dir/$output_tarname"
        set +x
      else
        set -x
        tar ${verbose_flag:-} ${compression_flag:-} \
            --create \
            -C "$dirname" \
            --file "$output_dir/$output_tarname" \
              "${filestotar[@]}"
        set +x
      fi
    fi
  fi
done

exit 0
