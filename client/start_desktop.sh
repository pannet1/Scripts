#!bin/env bash

export PATH="$PATH:$HOME/Scripts/client"
export PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND ;} history -a"
