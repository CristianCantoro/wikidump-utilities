#!/usr/bin/env bash

eval "$(docopts -V - -h - : "$@" <<EOF
Usage: merge_snapshots.sh [options] --input INPUT_FILE DATE

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
merge_snapshots.sh 0.1.0
copyright (c) 2016 Cristian Consonni
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

    if [[ ! -z $compression_command ]]; then
        echo -n "output compression: $output_compression"
        echo    " - compression commnand: $compression_command"
    else
        echo "ouput compression: None"
    fi
fi

echo "$DATE -> snapshot.$DATE.csv.gz"
zcat $(grep ".$DATE.csv.gz" $input) > snapshot.$DATE.csv.tmp
sort -n snapshot.$DATE.csv.tmp | $output_compression > snapshot.$DATE.csv.gz
rm snapshot.$DATE.csv.tmp
