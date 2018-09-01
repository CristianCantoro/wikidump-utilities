#!/usr/bin/env bash
#PBS -V
#PBS -l walltime=24:00:00
#PBS -l nodes=1:ncpus=1:ppn=1
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

function array_contains () {
    local seeking=$1; shift
    local in=1
    for element; do
        if [[ "$element" == "$seeking" ]]; then
            in=0
            break
        fi
    done
    return $in
}

function check_choices() {
  local mychoice="$1"
  declare -a choices="($2)"

  set +u
  if ! array_contains "$mychoice" "${choices[@]}"; then
    (>&2 echo -n "$mychoice is not within acceptable choices: {")
    (echo -n "${choices[@]}" | sed -re 's# #, #g' >&2)
    (>&2 echo '}' )
    exit 1
  fi
  set -u

}
#################### end: helpers

#################### usage
function short_usage() {
  (>&2 echo \
"Usage:
  job_wikilink_extraction_hpc.sh [options] ( -b | -z ) -i INPUTFILE
                                 -o OUTPUTDIR JOBNAME [jobargs]"
  )
}

function usage() {
  (>&2 short_usage )
  (>&2 echo \
"

Launch job on the HPC cluster, with input INPUTFILE and output OUTPUTDIR.

Arguments:
  -i INPUTFILE        Absolute path of the input file.
  -o OUTPUTDIR        Absolute path of the output directory.
  JOBNAME             Jobname to execute, choose from {extract-wikilinks,extract-redirects}.

Options:
  -b                  Use bz2 compression for the output, incompatible with -z
                      [default: 7z compression].
  -d                  Enable debug output.
  -m PYTHON_MODULE    Python module to use to lauch the job [default: infer from jobname].
  -p PYTHON_VERSION   Python version [default: 3.6].
  -v VENV_PATH        Absolute path of the virtualenv directory [default: \$PWD/wikidump].
  -z                  Use gzip compression for the output, incompatible with -b
                      [default: 7z compression].
  -h                  Show this help and exits.

Example:
  job_hpc.sh -i /home/user/input/20180301/enwiki-history1.7z) \
             -o /home/user/output \
              extract-wikilinks -l en")
}

declare -A JOB_MAP=( ['extract-wikilinks']='wikidump' \
                     ['extract-redirects']='wikidump' \
                     ['extract-snapshot']='graphsnapshot' \
                     )

declare -a JOB_CHOICES=()
for k in "${!JOB_MAP[@]}"; do
  JOB_CHOICES+=("$k")
done

help_flag=false
debug_flag=false
gzip_compression=false
bz2_compression=false

# required parameters
INPUTFILE=''
OUTPUTDIR=''
JOBNAME=''

# job args
declare -a jobargs

inputfile_unset=true
outputdir_unset=true

VENV_PATH="$PWD/wikidump"
PYTHON_VERSION='3.6'
LANGUAGE='en'

# Python module
PYTHON_MODULE=''
reference_module=''

while getopts ":bdhi:m:o:p:v:z" opt; do
  case $opt in
    b)
      bz2_compression=true
      ;;
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
    o)
      outputdir_unset=false
      check_dir "$OPTARG"

      OUTPUTDIR="$OPTARG"
      ;;
    m)
      PYTHON_MODULE="$OPTARG"
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

if $bz2_compression && $gzip_compression; then
  (>&2 echo "Options -b and -z are mutually exclusive.")
  short_usage
  exit 1
fi

# Shell Script: is mixing getopts with positional parameters possible?
# https://stackoverflow.com/q/11742996/2377454
numopt="$#"
if (( numopt-OPTIND < 0 )) ; then
  (>&2 echo "Error. Parameter JOBNAME is required.")
  short_usage
  exit 1
fi

JOBNAME="${*:$OPTIND:1}"
check_choices "$JOBNAME" "${JOB_CHOICES[*]}"
IFS=" " read -r -a jobargs <<< "${@:$OPTIND+1}"

if [ -z "$PYTHON_MODULE" ]; then
  reference_module="${JOB_MAP[$JOBNAME]}"
else
  reference_module="$PYTHON_MODULE"
fi

if [ -z "$PYTHON_MODULE" ]; then
  (>&2 echo "Error. Could not infer PYTHON_MODULE.")
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

#################### debug info
echodebug "Arguments:"
echodebug "  * INPUTFILE (-i): $INPUTFILE"
echodebug "  * OUTPUTDIR (-o): $OUTPUTDIR"
echodebug "  * JOBNAME: $JOBNAME"
echodebug

echodebug "Options:"
echodebug "  * bz2_compression (-b): $bz2_compression"
echodebug "  * debug_flag (-d): $debug_flag"
echodebug "  * PYTHON_MODULE (-m): $PYTHON_MODULE"
echodebug "  * PYTHON_VERSION (-p): $PYTHON_VERSION"
echodebug "  * VENV_PATH (-v): $VENV_PATH"
echodebug "  * gzip_compression (-z): $gzip_compression"
echodebug

if $debug_flag; then
  echodebug "inferred python module: $reference_module"
  echodebug "Job args:"
  for i in "${!jobargs[@]}"; do
    echodebug "  - jobargs[$i]: " "${jobargs[$i]}"
  done
fi
#################### end: debug info

########## start job
echo "job running on: $(hostname)"

set +u
# shellcheck disable=SC1090
source "$VENV_PATH/bin/activate"
set -u

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

if $bz2_compression; then
  compression_method='bz2'
fi

options=('--output-compression' "$compression_method")
echodebug "Compression method:" "${options[@]}"

# add locally-installed executables to PATH
if [[ -d "$HOME/bin" ]]; then
  export PATH="$PATH:$HOME/bin/"
fi

if [[ -d "$HOME/usr/bin" ]]; then
  export PATH="$PATH:$HOME/usr/bin/"
fi

if [[ -d "$HOME/usr/local/bin" ]]; then
  export PATH="$PATH:$HOME/usr/local/bin/"
fi

# python3 -m wikidump \
#   --output-compression 7z \
#     <input_files> \
#     <output_dir> \
#       extract-wikilinks -l en
set -x
$reference_python -m "$reference_module" \
  "${options[@]}" \
      "$INPUTFILE" \
      "$OUTPUTDIR" \
        "$JOBNAME" "${jobargs[@]:-}"
set +x

exit 0
