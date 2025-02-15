#!/bin/env bash

# Specify the location of the bash history file
HISTFILE=~/.bash_history

# Load the history file to ensure it's accessible in a non-interactive shell
set -o history

if [ $# -eq 0 ]; then
  history
else
  history | grep "$1"
fi
