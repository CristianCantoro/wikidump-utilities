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
#################### end: helpers

#################### usage
function short_usage() {
  (>&2 echo \
"Usage:
  tellhostname.sh [options] -c CLUSTERDIR -i INPUTDIR -o OUTPUTDIR")
}

function usage() {
  (>&2 short_usage )
  (>&2 echo \
"

Create symbolic links to the following directories:
  - <cluster_dir> -> /tmp/cconsonni/shared/cluster
  - <input_dir>   -> /tmp/cconsonni/shared/input
  - <output_dir>  -> /tmp/cconsonni/shared/output

Arguments:
  -c CLUSTERDIR       Absolute path of the cluster directory to link.
  -i INPUTDIR         Absolute path of the input directory to link.
  -o OUTPUTDIR        Absolute path of the output directory to link.

Options:
  -d                  Enable debug output.
  -p PYTHON_VERSION   Python version [default: 3.5].
  -u CLUSTER_USER     Cluster user name [default: \$USER].
  -v VENVNAME         Name of the python virtualenv [default: wikidump].
  -h                  Show this help and exits.

Example:
  tellhostname.sh -v /mnt/nxdata/")
}


help_flag=false
debug_flag=false

CLUSTER_USER="$USER"

# directories
CLUSTERDIR=''
INPUTDIR=''
OUTPUTDIR=''

clusterdir_unset=true
outputdir_unset=true
inputdir_unset=true

VENVNAME='wikidump'
PYTHON_VERSION='3.5'

while getopts ":c:dhi:o:p:u:v:" opt; do
  case $opt in
    c)
      clusterdir_unset=false
      check_dir "$OPTARG"

      CLUSTERDIR="$OPTARG"
      ;;
    i)
      inputdir_unset=false
      check_dir "$OPTARG"

      INPUTDIR="$OPTARG"
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
      VENVNAME="$OPTARG"
      ;;
    u)
      CLUSTER_USER="$OPTARG"
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

if $clusterdir_unset; then
  (>&2 echo "Error. Option -c is required.")
  short_usage
  exit 1
fi

if $inputdir_unset; then
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

echo "tellhostname.sh"
echodebug "CLUSTER_USER: $CLUSTER_USER"
echodebug "CLUSTERDIR: $CLUSTERDIR"
echodebug "OUTPUTDIR: $OUTPUTDIR"
echodebug "INPUTDIR: $INPUTDIR"
echodebug "VENVNAME: $VENVNAME"
echodebug "PYTHON_VERSION: $PYTHON_VERSION)"

reference_python="$(command -v "python${PYTHON_VERSION}")"
echodebug "reference Python path: $reference_python"

set -x

# create /tmp/cconsonni
tmpdir="/tmp/$CLUSTER_USER"
mkdir -p "$tmpdir"


# create /tmp/cconsonni/shared
# making sure to eliminate it, if it was already present and it was not a
# symbolic link.
shared_path="/tmp/$CLUSTER_USER/shared"
if [ ! -L "$shared_path" ] && [ -d "$shared_path" ]; then
  rm -r "$shared_path"
fi
mkdir -p "$shared_path"

# create symbolic links:
#   <cluster_dir> -> /tmp/cconsonni/shared/cluster
#   <input_dir>   -> /tmp/cconsonni/shared/input
#   <output_dir>  -> /tmp/cconsonni/shared/output
ln -sf "$CLUSTERDIR" "$shared_path/cluster"
ln -sf "$INPUTDIR" "$shared_path/input"
ln -sf "$OUTPUTDIR" "$shared_path/output"

# create a working dir /tmp/cconsonni/shared/cluster/tellhostname
base_dir="$shared_path/cluster/tellhostname"
mkdir -p "$base_dir"

export VIRTUALENVWRAPPER_PYTHON="$reference_python"

set +xeuo pipefail
# shellcheck disable=SC1090
source "$shared_path/cluster/$VENVNAME/bin/activate"
set -xeuo pipefail

hostname           > "$base_dir/host.$(hostname)"
python3 --version  > "$base_dir/host.$(hostname).python"
command -v python3 > "$base_dir/host.$(hostname).whichpython"
pip freeze         > "$base_dir/host.$(hostname).freeze"

sleep 1m

exit 0
