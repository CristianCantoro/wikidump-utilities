#!/bin/bash

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
    cd $output_dir
    count=$(ls -1 2>/dev/null | grep ".csv.gz" | wc -l)
    if [ $count -gt 0 ]; then
	filename=$(basename "$inputfile")
        output_pattern="$filename.features.*.csv.gz"

	tar_flags="cfz"
        if $verbose; then
	   tar_flags="cvfz"

            echo -n "tar cvfz ${output_dir}$filename.features.csv.tar.gz "
            echo    "${output_dir}$output_pattern"
        fi

        tar $tar_flags ${output_dir}$filename.features.csv.tar.gz \
            ${output_dir}$output_pattern

        # rm ${output_dir}$output_pattern
    fi

done
