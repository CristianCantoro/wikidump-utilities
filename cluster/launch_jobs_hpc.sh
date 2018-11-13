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
  local option="$2"

  if [[ ! -d "$mydir" ]]; then
    (>&2 echo "Error in option '$option': $mydir is not a valid directory.")
    exit 1
  fi
  if ! is_abs_path "$mydir"; then
    (>&2 echo "Error in option '$option': $mydir is not an absolute path.")
    exit 1
  fi

}

function check_file() {
  local myfile="$1"
  local option="$2"

  if [[ ! -e "$myfile" ]]; then
    (>&2 echo "Error in option '$option': $myfile is not a valid file.")
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

function check_posint() {
  local re='^[0-9]+$'
  local mynum="$1"
  local option="$2"

  if ! [[ "$mynum" =~ $re ]] ; then
     (echo -n "Error in option '$option': " >&2)
     (echo "must be a positive integer, got $mynum." >&2)
     exit 1
  fi

  if ! [ "$mynum" -gt 0 ] ; then
     (echo "Error in option '$option': must be positive, got $mynum." >&2)
     exit 1
  fi
}
#################### end: helpers

#################### usage
function short_usage() {
  (>&2 echo \
"Usage:
  launch_wikilink_extraction_hpc.sh [options] \\
                                    [ -c PBS_NCPUS -n PBS_NODES ] \\
                                    [ -b | -z ] \\
                                    -i INPUT_LIST \\
                                    -o OUTPUTDIR
                                    JOBNAME"
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
  JOBNAME             Jobname to execute, choose from {extract-wikilinks,
                      extract-redirects, extract-revisionlist, extract-snapshot}.

Options:
  -b                  Use bz2 compression for the output [default: 7z compression].
  -c PBS_NCPUS        Number of PBS cpus to request (needs also -n and -P to be specified).
  -d                  Enable debug output.
  -m PYTHON_MODULE    Python module to use to lauch the job [default: infer from jobname].
  -n PBS_NODES        Number of PBS nodes to request (needs also -c  and -P to be specified).
  -p PYTHON_VERSION   Python version [default: 3.6].
  -P PBS_PPN          Number of PBS processors per node to request (needs also -n  and -P to be specified).
  -q PBS_QUEUE        PBS queue name [default: cpuq].
  -v VENV_PATH        Absolute path of the virtualenv directory [default: \$PWD/wikidump].
  -w PBS_WALLTIME     Max walltime for the job, a time period formatted as hh:mm:ss.
  -z                  Use gzip compression for the output [default: 7z compression].
  -h                  Show this help and exits.

Example:
  launch_jobs_hpc.sh  -i /home/user/input/input_list.txt \\
                      -o /home/user/output \\
                        extract-wikilinks -l en")
}

declare -A JOB_MAP=( ['extract-wikilinks']='wikidump' \
                     ['extract-redirects']='wikidump' \
                     ['extract-revisionlist']='wikidump' \
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

# Python module
PYTHON_MODULE=''
reference_module=''

# PBS
pbs_nodes_set=false
pbs_ppn_set=false
pbs_ncpus_set=false

PBS_QUEUE='cpuq'
PBS_NCPUS=''
PBS_NODES=''
PBS_PPN=''
PBS_WALLTIME=''

while getopts ":bc:dhi:m:n:o:p:P:q:v:w:z" opt; do
  case $opt in
    b)
      bz2_compression=true
      ;;
    c)
      check_posint "$OPTARG" '-c'

      pbs_ncpus_set=true
      PBS_NCPUS="$OPTARG"
      ;;
    i)
      inputlist_unset=false
      check_file "$OPTARG" '-i'

      INPUT_LIST="$OPTARG"
      ;;
    d)
      debug_flag=true
      ;;
    h)
      help_flag=true
      ;;
    m)
      PYTHON_MODULE="$OPTARG"
      ;;
    n)
      check_posint "$OPTARG" '-n'

      pbs_nodes_set=true
      PBS_NODES="$OPTARG"
      ;;
    o)
      outputdir_unset=false
      check_dir "$OPTARG" '-o'

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
    P)
      check_posint "$OPTARG" '-P'

      pbs_ppn_set=true
      PBS_PPN="$OPTARG"
      ;;
    q)
      PBS_QUEUE="$OPTARG"
      ;;
    v)
      check_dir "$OPTARG" '-v'

      VENV_PATH="$OPTARG"
      ;;
    w)
      PBS_WALLTIME="$OPTARG"
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

# PBS nodes, PBS ncpus and PBS ppn must be set all togheter.
# A xor B == ( A or B ) && ( not ( A && B ) )
if ($pbs_nodes_set || $pbs_ncpus_set) && \
    ! ($pbs_nodes_set && $pbs_ncpus_set); then
  (>&2 echo "Options -c, -n, -P must be specified togheter.")
  short_usage
  exit 1
fi

if ($pbs_nodes_set || $pbs_ppn_set) && \
    ! ($pbs_nodes_set && $pbs_ppn_set); then
  (>&2 echo "Options -c, -n, -P must be specified togheter.")
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
IFS=' ' read -r -a jobargs <<< "${@:$OPTIND+1}"

if [ -z "$PYTHON_MODULE" ]; then
  reference_module="${JOB_MAP[$JOBNAME]}"
else
  reference_module="$PYTHON_MODULE"
fi

if [ -z "$reference_module" ]; then
  (>&2 echo "Error. Could not infer PYTHON_MODULE.")
  short_usage
  exit 1
fi
#################### end: usage

#################### utils
if $debug_flag; then
  function echodebug() {
    (>&2 echo -en "[$(date '+%F_%H:%M:%S')][debug]\\t")
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
echodebug "  * PBS_NCPUS (-c): $PBS_NCPUS"
echodebug "  * debug_flag (-d): $debug_flag"
echodebug "  * PYTHON_MODULE (-m): $PYTHON_MODULE"
echodebug "  * PBS_NODES (-n): $PBS_NODES"
echodebug "  * PYTHON_VERSION (-p): $PYTHON_VERSION"
echodebug "  * PBS_PPN (-P): $PBS_PPN"
echodebug "  * PBS_QUEUE (-q): $PBS_QUEUE"
echodebug "  * VENV_PATH (-v): $VENV_PATH"
echodebug "  * PBS_WALLTIME (-w): $PBS_WALLTIME"
echodebug "  * gzip_compression (-z): $gzip_compression"
echodebug

if $debug_flag; then
  echodebug "=> inferred python module: $reference_module"
  if [ "${#jobargs[@]}" -gt '0' ] ; then
    echodebug "=> Job args:"
    for i in "${!jobargs[@]}"; do
      echodebug "    - jobargs[$i]: " "${jobargs[$i]}"
    done
    echodebug
  else
    echodebug "=> No extra job args provided"
  fi
fi

echodebug "scriptdir: $scriptdir"
#################### end: debug info

# input file regex:
# (1)      (2)                          (3)      (4)    (5)
# (en)wiki-(20180301)-pages-meta-history(1).xml-p(7640)p(9429).7z
inrgx='(.{2})wiki-([0-9]{8})-pages-meta-history([0-9]+)\.xml'
inrgx+='-p([0-9]+)p([0-9]+)(.*)\.(7z|gz|bz2)'

inrgx2='(.{2})wiki-([0-9]{8})-pages-meta-history\.xml'
inrgx2+='(.*)\.(7z|gz|bz2)'

compression_flag=''
if $gzip_compression; then
  compression_flag='-z'
fi

if $bz2_compression; then
  compression_flag='-b'
fi

debug_flag_job=''
if $debug_flag; then
  debug_flag_job='-d'
fi

declare -a pbsoptions
if [ ! -z "$PBS_WALLTIME" ]; then
  pbsoptions+=('-l' "walltime=$PBS_WALLTIME")
fi

if [ ! -z "$PBS_NODES" ]; then
  pbsoptions+=('-l' "nodes=$PBS_NODES:ncpus=$PBS_NCPUS:ppn=$PBS_PPN")
fi

while read -r infile; do
  echo "Processing $infile ..."

  filename="$(basename "$infile")"
  pbsjobname="$filename"
  if [[ "$filename" =~ $inrgx ]]; then
    # cluster jobname:
    # enwiki-20180301-pages-meta-history1.xml-p7640p9429.7z \
    #   -> en20180301-h1p7640p9429
    echodebug "inrgx: $inrgx"
    pbsjobname="$(echo "$filename" | sed -r 's/'"$inrgx"'/\1-\2-h\3p\4p\5/')"
  elif [[ "$filename" =~ $inrgx2 ]]; then
    # svwiki-20180301-pages-meta-history.xml.7z.features.xml.gz \
    #   -> sv20180301-h
    echodebug "inrgx2: $inrgx2"
    pbsjobname="$(echo "$filename" | sed -r 's/'"$inrgx2"'/\1-\2-h/')"
  fi
  pbsjobname="${JOBNAME}.${pbsjobname}"

  echodebug "filename: $filename"  
  echodebug "pbsjobname: $pbsjobname"

  # qsub -N <pbsjobname> -q cpuq -- \
  #   <scriptdir>/job_hpc.sh -v <venv_path> -i <input_file> -o <output_dir>
  set -x
  qsub -N "$pbsjobname" -q "$PBS_QUEUE" "${pbsoptions[@]:-}" -- \
   "$scriptdir/job_hpc.sh" \
     ${compression_flag:-} \
     ${debug_flag_job:-} \
     -v "$VENV_PATH" \
     -i "$infile" \
     -m "$reference_module" \
     -o "$OUTPUTDIR" \
     -p "$PYTHON_VERSION" \
      "$JOBNAME" "${jobargs[@]:-}"
  set +x

done < "$INPUT_LIST"

exit 0
