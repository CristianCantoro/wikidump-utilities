#!/usr/bin/env bash
#PBS -V
#PBS -l walltime=00:02:00
#PBS -l nodes=1:ncpus=1:ppn=1
#PBS -q cpuq

#shellcheck disable=SC2128
SOURCED=false && [ "$0" = "$BASH_SOURCE" ] || SOURCED=true
if ! $SOURCED; then
  set -euo pipefail
  IFS=$'\n\t'
fi

i="$1"

echo "Testing $0 ($2): countdown for $i seconds ..."
while ((i>0)); do
  echo "$i"
  sleep 1
  i=$((i-1))
done
echo "Done!"

exit 0

