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
  launch_wikilink_extraction_hpc.sh [options] ( -b | -z ) -i INPUT_LIST
                                    -o OUTPUTDIR"
  )
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
  JOBNAME             Jobname to execute, choose from {extract-wikilinks, extract-redirects}.

Options:
  -b                  Use bz2 compression for the output [default: 7z compression].
  -d                  Enable debug output.
  -p PYTHON_VERSION   Python version [default: 3.6].
  -v VENV_PATH        Absolute path of the virtualenv directory [default: \$PWD/wikidump].
  -z                  Use gzip compression for the output [default: 7z compression].
  -h                  Show this help and exits.

Example:
  launch_jobs_hpc.sh  -i /home/user/input/input_list.txt \
                      -o /home/user/output \
                        extract-wikilinks -l en")
}

declare -a JOB_CHOICES=('extract-wikilinks' 'extract-redirects')

help_flag=false
debug_flag=false
gzip_compression=false
bz2_compression=false

# arguments
INPUT_LIST=''
OUTPUTDIR=''
JOBNAME=''

# job args
declare -a jobargs

outputdir_unset=true
inputlist_unset=true

VENV_PATH="$PWD/wikidump"
PYTHON_VERSION='3.6'
LANGUAGE='en'

while getopts ":bdhi:o:p:v:z" opt; do
  case $opt in
    b)
      bz2_compression=true
      ;;
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

#################### debug info
echodebug "Arguments:"
echodebug "  * INPUT_LIST (-i): $INPUT_LIST"
echodebug "  * OUTPUTDIR (-o): $OUTPUTDIR"
echodebug "  * JOBNAME: $JOBNAME"
echodebug

echodebug "Options:"
echodebug "  * bz2_compression (-b): $bz2_compression"
echodebug "  * debug_flag (-d): $debug_flag"
echodebug "  * PYTHON_VERSION (-p): $PYTHON_VERSION"
echodebug "  * VENV_PATH (-v): $VENV_PATH"
echodebug "  * gzip_compression (-z): $gzip_compression"
echodebug

if $debug_flag; then
  echodebug "Job args:"
  for i in "${!jobargs[@]}"; do
    echodebug "  - jobargs[$i]: " "${jobargs[$i]}"
  done
  echodebug
fi

echodebug "scriptdir: $scriptdir"
#################### end: debug info

# input file regex:
# (1)      (2)                          (3)      (4)    (5)
# (en)wiki-(20180301)-pages-meta-history(1).xml-p(7640)p(9429).7z
inrgx='(.{2})wiki-([0-9]{8})-pages-meta-history([0-9]+)\.xml'
inrgx+='-p([0-9]+)p([0-9]+)\.7z'

compression_flag=''
if $gzip_compression; then
  compression_flag='-z'
fi

if $bz2_compression; then
  compression_flag='-b'
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
     ${compression_flag:-} \
     -v "$VENV_PATH" \
     -i "$infile" \
     -o "$OUTPUTDIR" \
     -p "$PYTHON_VERSION" \
      "$JOBNAME" "${jobargs[@]:-}"
  set +x

done < "$INPUT_LIST"

exit 0
