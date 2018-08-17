#!/usr/bin/env bash
#PBS -V
#PBS -l walltime=12:00:00
#PBS -l select=1:ncpus=1
#PBS -q cpuq

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
  job_hpc.sh [options] -i INPUTFILE -o OUTPUTDIR")
}

function usage() {
  (>&2 short_usage )
  (>&2 echo \
"

Launch job on the HPC cluster, with input INPUTFILE and output OUTPUTDIR.

Arguments:
  -i INPUTFILE        Absolute path of the input file.
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
  job_hpc.sh \
    -i /home/cristian.consonni/input \
    -o /home/cristian.consonni/output")
}

help_flag=false
debug_flag=false
gzip_compression=false

# directories
INPUTFILE=''
OUTPUTDIR=''

outputdir_unset=true
inputfile_unset=true

VENV_PATH="$PWD/wikidump"
PYTHON_VERSION='3.6'
LANGUAGE='en'

while getopts ":dhi:l:o:p:v:z" opt; do
  case $opt in
    i)
      inputfile_unset=false
      check_file "$OPTARG"

      INPUTFILE="$OPTARG"
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

if $inputfile_unset; then
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

########## vars
echodebug "INPUTFILE: $INPUTFILE"
echodebug "OUTPUTDIR: $OUTPUTDIR"
echodebug "PYTHON_VERSION: $PYTHON_VERSION"
echodebug "VENV_PATH: $VENV_PATH"
echodebug "LANGUAGE: $LANGUAGE"

########## start job
echo "job running on: $(hostname)"

# shellcheck disable=SC1090
source "$VENV_PATH/bin/activate"

reference_python="$(command -v "python${PYTHON_VERSION}")"
echodebug "reference Python path: $reference_python"

if [ -z "$reference_python" ]; then
  (>&2 echo "Error. No reference Python found for version: $PYTHON_VERSION")
  exit 1
fi

compression_method='7z'
if $gzip_compression; then
  compression_method='gzip'
fi

options=('--output-compression' "$compression_method")
echodebug "Compression method:" "${options[@]}"

export PATH="$PATH:/home/cristian.consonni/usr/bin/:/home/cristian.consonni/usr/local/bin/"

# python3 -m wikidump \
#   --output-compression 7z \
#     <input_files> \
#     <output_dir> \
#       extract-wikilinks -l en
$reference_python -m wikidump \
  "${options[@]}" \
      "$INPUTFILE" \
      "$OUTPUTDIR" \
        extract-wikilinks -l "$LANGUAGE"

exit 0
