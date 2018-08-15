#!/usr/bin/env bash
#PBS -V
#PBS -l walltime=12:00:00
#PBS -l select=1:ncpus=1
#PBS -q cpuq

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

List interfaces with their IPv4 address, if none is specified list only the
ones that are assigned an IPv4 address.

If a interface with no address is specified then the string 'no address' is
printed.

Arguments:
  -i INPUTFILE        Absolute path of the input file.
  -o OUTPUTDIR        Absolute path of the output directory.

Options:
  -d                  Enable debug output.
  -p PYTHON_VERSION   Python version [default: 3.6].
  -v VENV_PATH        Absolute path of the virtualenv directory
                      [default: \$PWD/wikidump].
  -h                  Show this help and exits.

Example:
  job_hpc.sh \
    -i /home/cristian.consonni/input \
    -o /home/cristian.consonni/output")
}

help_flag=false
debug_flag=false

# directories
INPUTFILE=''
OUTPUTDIR=''

outputdir_unset=true
inputfile_unset=true

VENV_PATH="$PWD/wikidump"
PYTHON_VERSION='3.6'

while getopts ":dhi:o:p:v:" opt; do
  case $opt in
    i)
      inputfile_unset=false
      check_file "$OPTARG"

      INPUTFILE="$OPTARG"
      ;;
    o)
      outputdir_unset=false
      check_dir "$OPTARG"

      OUTPUTDIR="$OPTARG"
      ;;
    d)
      debug_flag=true
      ;;
    h)
      help_flag=true
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
    echo -en "[$(date '+%F_%k:%M:%S')][debug]\\t"
    echo "$@" 1>&2
  }
else
  function echodebug() { true; }
fi
####################

########## vars
VENV_PATH="$HOME/ngi/wikidump/cluster/wlnew-venv"
INPUTFILE="$HOME/ngi/wikidump/input"
OUTPUTDIR="$HOME/ngi/wikidump/output"

echodebug "VENV_PATH: $VENV_PATH"
echodebug "INPUTFILE: $INPUTFILE"
echodebug "OUTPUTDIR: $OUTPUTDIR"
echodebug "PYTHON_VERSION: $PYTHON_VERSION"

reference_python="$(command -v "python${PYTHON_VERSION}")"
echodebug "reference Python path: $reference_python"

if [ -z "$reference_python" ]; then
  (>&2 echo "Error. No reference Python found for version: $PYTHON_VERSION")
  exit 1
fi

########## start job
echo "job running on: $(hostname)"

# shellcheck disable=SC1090
source "$VENV_PATH/bin/activate"

# python3 -m wikidump \
#   --output-compression 7z \
#     <input_files> \
#     <output_dir> \
#       extract-wikilinks -l en
$reference_python -m wikidump \
  --output-compression 7z \
      "$INPUTFILE" \
      "$OUTPUTDIR"
        extract-wikilinks -l en

exit 0
