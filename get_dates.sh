#!/usr/bin/env bash

# enwiki-20150901-pages-meta-history12.xml
#	-p002133362p002207924.7z.features.xml.7z.features.2003-03-15.csv.gz
regex=''
regex=${regex}"enwiki-20150901-pages-meta-history[0-9]{1,2}\.xml"
regex=${regex}"-p[0-9]{9}p[0-9]{9}.7z.features.xml.7z.features."
regex=${regex}"([0-9]{4})-([0-9]{2})-([0-9]{2}).csv.gz"

while IFS='' read -r file_fullpath || [[ -n "$file_fullpath" ]]; do
    filename=$(basename $file_fullpath)

    year=''
    month=''
    day=''
    if [[ $filename =~ $regex ]]; then
        year="${BASH_REMATCH[1]}"
        month="${BASH_REMATCH[2]}"
        day="${BASH_REMATCH[3]}"
        # echo "date: $year - $month - $day --- ${filename}"
    else
        echo "$filename doesn't match" >&2
    fi

    echo "$year-$month-$day"

done < "$1"
