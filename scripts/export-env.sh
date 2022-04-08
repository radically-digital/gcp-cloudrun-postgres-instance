#!/bin/bash

## Usage
## . ./export-env.sh <some-other.env>

ENV_FILE="${1:-.env}"

unamestr=$(uname)
if [ "$unamestr" = 'Linux' ]; then
  echo $(grep -v '^#' "$ENV_FILE" | sed -En "s|(.*)=.*|exporting \"\1\"|p" | xargs -d '\n')
  export $(grep -v '^#' "$ENV_FILE" | xargs -d '\n')
else
  echo $(grep -v '^#' "$ENV_FILE" | sed -En "s|(.*)=.*|exporting \"\1\"|p" | xargs -0)
  export $(grep -v '^#' "$ENV_FILE" | xargs -0)
fi

echo "done!"
