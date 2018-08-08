#!/usr/bin/env bash
set -eu
IFS=$'\n\t'

export SHARED_PATH='/tmp/spark'

if [ ! -w "$SHARED_PATH" ]; then
  ln -s "$HOME/spark/" "$SHARED_PATH"
else
  if [[ -L "$SHARED_PATH" && -d "$SHARED_PATH" ]]
  then
      echo "$SHARED_PATH is a symlink to a directory"
  fi
fi

source '/tmp/spark/deployment/scripts/envvars.sh'

set +eu
source "${SHARED_PATH}/deployment/${SPARKDIR_NAME}/bin/find-spark-home"
set -eu

set +eu
source "$VENV_PATH/bin/activate"
set -eu

echo "$(hostname)" '==>' "$@"
"$@"
