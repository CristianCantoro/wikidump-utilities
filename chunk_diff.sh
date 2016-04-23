#!/usr/bin/env bash
eval "$(docopts -V - -h - : "$@" <<EOF
Usage: chunk_diff.sh [options] FILE1 FILE2

      FILE1                The first file to compare
      FILE2                The second file to compare
      -d, --debug          Enable debug mode.
      -n, --lines N        Number of lines for each chunk (passed to head/tail).
                           (default: 10)
      -s, --strict         Stop as soon as you find two chunks that differ.
      -v, --verbose        Print unified diff format (more verbose).
      -h, --help           Show this help message and exits.
      --version            Print version and copyright information.
----
chunk_diff.sh 0.1.0
copyright (c) 2016 Cristian Consonni
MIT License
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.
EOF
)"

set -euo pipefail
IFS=$'\n\t'

regex="([0-9]+)c([0-9]+)"

nlines_1=0
nlines_2=0

nlines_1=`cat $1 | wc -l`
nlines_2=`cat $2 | wc -l`

if [[ $nlines_1 != $nlines_2 ]]; then
    echo "The two files have a different number of lines."
    exit 1
fi

chunklines=10
if [[ $lines -gt 0 ]]; then
    chunklines=$lines
fi

nlines=$nlines_1

nchunks=$(( $nlines / $chunklines ))
reminder=$(( $nlines - $nchunks * $chunklines ))
if [[ $reminder -gt 0 ]]; then
    nchunks=$(( $nchunks + 1 ))
fi

if $debug; then
    echo "The two files have the same number of lines: $nlines"
    echo "each chunk will have $chunklines lines"
    echo "-> there will be $nchunks chunks"
fi

chuck_line_start=0
chuck_line_stop=-1
exitstatus=0
diffstatus=0
for (( nc = 0; nc < ${nchunks}; nc++ )); do
    chunk_line_start=$(( $chunklines * $nc ))
    chunk_line_stop=$(( $chunklines * $(( nc + 1 )) ))

    tmpfile1="$1.tmp.chunk$nc"
    tmpfile2="$2.tmp.chunk$nc"
    chunkfile1="$1.chunk$nc"
    chunkfile2="$2.chunk$nc"

    if $debug; then
        echo "$chunk_line_start - $chunk_line_stop"
    fi

    if [[ $chunk_line_start -eq 0 ]]; then
        if $debug; then
            echo "head -n$chunklines $1"
        fi

        head -n$chunklines $1 > $chunkfile1
        head -n$chunklines $2 > $chunkfile2

        diff $chunkfile1 $chunkfile2

    else
        cls=$(( chunk_line_start + 1 ))

        if $debug; then
            echo "tail -n+$cls $1 | head -n$chunklines > $chunkfile1"
        fi

        tail -n+$cls $1 > $tmpfile1
        head -n$chunklines $tmpfile1 > $chunkfile1

        tail -n+$cls $2 > $tmpfile2
        head -n$chunklines $tmpfile2 > $chunkfile2

        rm $tmpfile1 $tmpfile2        
    fi

    diffstatus=$(diff -U 0 $chunkfile1 $chunkfile2 | grep -c '^@' || true)

    if [[ $diffstatus -gt 0 ]]; then
        if [[ $(diff $chunkfile1 $chunkfile2) =~ $regex ]]; then
            c1="${BASH_REMATCH[1]}"
            c2="${BASH_REMATCH[2]}"
            echo "$(( $c1 + $chunk_line_start ))c$(( $c2 + $chunk_line_start ))" 
        fi

        diff $chunkfile1 $chunkfile2 | grep -v '^[0-9]\+c' || true

        exitstatus=$diffstatus
    fi

    rm $chunkfile1 $chunkfile2

    if [[ $diffstatus -gt 0 ]] && $strict; then
        exit $diffstatus
    fi
done

exit $exitstatus