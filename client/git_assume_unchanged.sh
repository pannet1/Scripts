#!/usr/bin/env bash

if [ -z "$1" ]; then
  echo "Operation canceled."
  exit 1
else
  git update-index --assume-unchanged "$1"
fi
