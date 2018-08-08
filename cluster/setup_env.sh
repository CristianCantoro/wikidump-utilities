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
  setup_env.sh [options] -v VENV_PATH")
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
  -v VENV_PATH        Absolute path of the virtualenv directory.

Options:
  -d                  Enable debug output.
  -h                  Show this help and exits.

Example:
  setup_env.sh -v /tmp/cconsonni/shared/cluster/wikidump")
}


help_flag=false
debug_flag=false

venvpath_unset=true
VENV_PATH=''

while getopts ":hv:" opt; do
  case $opt in
    h)
      help_flag=true
      ;;
    v)
      venvpath_unset=false
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

if $venvpath_unset; then
  (>&2 echo "Error. Option -v is required.")
  short_usage
  exit 1
fi

if $help_flag; then
  usage
  exit 0
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


set +euo pipefail
# shellcheck disable=SC1090
source "$VENV_PATH/bin/activate"
set -euo pipefail

args=("$@")
echo "$(hostname)" "==>" "${args[@]:2}"
set -x
"${args[@]:2}"
