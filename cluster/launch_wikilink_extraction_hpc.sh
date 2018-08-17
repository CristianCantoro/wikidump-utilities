#!/usr/bin/env bash

#shellcheck disable=SC2128
SOURCED=false && [ "$0" = "$BASH_SOURCE" ] || SOURCED=true

if ! $SOURCED; then
  set -euo pipefail
  IFS=$'\n\t'
fi

#################### helpers
# check if path is absolute
# https://stackoverflow.com/a/20204890/2377454
function is_abs_path() {
  local isabs=false
  local mydir="$1"

  case $mydir in
    /*)
      # 0 is true
      isabs=0
      ;;
    *)
      # 1 is false
      isabs=1
      ;;
  esac

  return $isabs
}

function check_dir() {
  local mydir="$1"

  if [[ ! -d "$mydir" ]]; then
    (>&2 echo "$mydir is not a valid directory.")
    exit 1
  fi
  if ! is_abs_path "$mydir"; then
    (>&2 echo "$mydir is not an absolute path.")
    exit 1
  fi

}

function check_file() {
  local myfile="$1"

  if [[ ! -e "$myfile" ]]; then
    (>&2 echo "$myfile is not a valid file.")
    exit 1
  fi

}
#################### end: helpers

#################### usage
function short_usage() {
  (>&2 echo \
"Usage:
  launch_wikilink_extraction_hpc.sh [options] -i INPUT_LIST -o OUTPUTDIR")
}

function usage() {
  (>&2 short_usage )
  (>&2 echo \
"

Launch list of jobs on the HPC cluster from INPUT_LIST and output results in
OUTPUTDIR.

Arguments:
  -i INPUT_LIST       Absolute path of the input file.
  -o OUTPUTDIR        Absolute path of the output directory.

Options:
  -d                  Enable debug output.
  -p PYTHON_VERSION   Python version [default: 3.6].
  -v VENV_PATH        Absolute path of the virtualenv directory
                      [default: \$PWD/wikidump].
  -z                  Use gzip compression for the output
                      [default: 7z compression].
  -h                  Show this help and exits.

Example:
  launch_wikilink_extraction_hpc.sh  /home/cristian.consonni/input")
}

help_flag=false
debug_flag=false
gzip_compression=false

# directories
INPUT_LIST=''
OUTPUTDIR=''

outputdir_unset=true
inputlist_unset=true

VENV_PATH="$PWD/wikidump"
PYTHON_VERSION='3.6'
LANGUAGE='en'

while getopts ":dhi:l:o:p:v:z" opt; do
  case $opt in
    i)
      inputlist_unset=false
      check_file "$OPTARG"

      INPUT_LIST="$OPTARG"
      ;;
    d)
      debug_flag=true
      ;;
    h)
      help_flag=true
      ;;
    l)
      LANGUAGE="$OPTARG"
      ;;
    o)
      outputdir_unset=false
      check_dir "$OPTARG"

      OUTPUTDIR="$OPTARG"
      ;;
    p)
      pyver="$OPTARG"

      if ! command -v "python${pyver}" >/dev/null; then
        (2>& echo "Error. version $pyver of Python you requested seems not " )
        (2>& echo "to be installed on this system." )
        exit 1
      fi

      PYTHON_VERSION="$OPTARG"
      ;;
    v)
      check_dir "$OPTARG"
      VENV_PATH="$OPTARG"
      ;;
    z)
      gzip_compression=true
      ;;
    \?)
      (>&2 echo "Error. Invalid option: -$OPTARG")
      exit 1
      ;;
    :)
      (>&2 echo "Error.Option -$OPTARG requires an argument.")
      exit 1
      ;;
  esac
done

if $help_flag; then
  usage
  exit 0
fi

if $inputlist_unset; then
  (>&2 echo "Error. Option -i is required.")
  short_usage
  exit 1
fi

if $outputdir_unset; then
  (>&2 echo "Error. Option -o is required.")
  short_usage
  exit 1
fi
#################### end: usage

#################### utils
if $debug_flag; then
  function echodebug() {
    (>&2 echo -en "[$(date '+%F_%k:%M:%S')][debug]\\t")
    (>&2 echo "$@" 1>&2)
  }
else
  function echodebug() { true; }
fi
####################

scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

#################### vars
echodebug "INPUT_LIST: $INPUT_LIST"
echodebug "OUTPUTDIR: $OUTPUTDIR"
echodebug "PYTHON_VERSION: $PYTHON_VERSION"
echodebug "VENV_PATH: $VENV_PATH"
echodebug "LANGUAGE: $LANGUAGE"

echodebug "scriptdir: $scriptdir"
#################### end: vars

# input file regex:
# (1)      (2)                          (3)      (4)    (5)
# (en)wiki-(20180301)-pages-meta-history(1).xml-p(7640)p(9429).7z
inrgx='(.{2})wiki-([0-9]{8})-pages-meta-history([0-9]+)\.xml'
inrgx+='-p([0-9]+)p([0-9]+)\.7z'

compression_flag=''
if $gzip_compression; then
  compression_flag='-z'
fi

while read -r infile; do
  echo "Processing $infile ..."

  filename="$(basename "$infile")"
  # jobname:
  # enwiki-20180301-pages-meta-history1.xml-p7640p9429.7z \
  #   -> en20180301-h1p7640p9429
  jobname="$(echo "$filename" | sed -r 's/'"$inrgx"'/\1-\2-h\3p\4p\5/')"

  echodebug "filename: $filename"  
  echodebug "jobname: $jobname"

  # qsub -N <jobname> -q cpuq -- \
  #   <scriptdir>/job_hpc.sh -v <venv_path> -i <input_file> -o <output_dir>
  set -x
  qsub -N "$jobname" -q cpuq -- \
   "$scriptdir/job_hpc.sh" \
     -v "$VENV_PATH" \
     -i "$infile" \
     -o "$OUTPUTDIR" \
     -p "$PYTHON_VERSION" \
     -l "$LANGUAGE" \
     ${compression_flag:-}
  set +x

done < "$INPUT_LIST"