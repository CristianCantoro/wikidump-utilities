#!/usr/bin/env bash

eval "$(docopts -V - -h - : "$@" <<EOF
Usage: pages_snapshot.sh [options] FILE [FILE ...] --output-dir OUTPUT_DIR

      FILE                                  File to parse.
      --output-dir OUTPUT_DIR               Output directory.
      --dry-run                             Do not output any file
      --output-compression {gzip,7z,None}   Output compression format
                                            (default: None).
      --last-date DATE                      Greatest timestamp in the dump
                                            (default: now).
      -v, --verbose                         Generate verbose output.
      -h, --help                            Show this help message and exits.
      --version                             Print version and copyright
                                            information.
----
pages_snapshot.sh 0.1.0
copyright (c) 2016 Cristian Consonni
MIT License
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.
EOF
)"

for inputfile in "${FILE[@]}"
do
    if $verbose; then
        echo "FILE: $inputfile"

        echo -n "/tmp/cristian.consonni/shared/cluster/scripts/setup_env.sh "
        echo -n "time "
        echo -n "python3.5 -m graphsnapshot --output-compression $output_compression "
        echo -n "$inputfile "
        echo -n "$output_dir "
        echo    "snapshot-extractor --last-date $last_date"
    fi
    # /tmp/cristian.consonni/shared/cluster/scripts/setup_env.sh \
    # time \
    # python3.5 -m graphsnapshot --output-compression $output_compression \
    #   $inputfile \
    #   $output_dir \
    #   snapshot-extractor --last-date "$last_date"

    count=`ls -1 *.csv.gz 2>/dev/null | wc -l`
    if [ $count -gt 0 ]; then
        if $verbose; then
            echo -n "tar cvfz \"$output_dir/$inputfile.features.csv.tar.gz\" "
            echo    "\"$output_dir/$inputfile*.csv.gz\""
        fi

        # tar cvfz "$output_dir/$inputfile.features.csv.tar.gz" \
        #   "$output_dir/$inputfile*.csv.gz"
    fi

done


