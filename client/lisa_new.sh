#!/usr/bin/env bash
if [ -z "$1" ]; then
	echo "You need to provide <task number> <branch name>"
	exit 1
elif [$1 -lt 10]; then
	echo "<task number> should be greater than 10"
else
	git checkout development
	git pull origin development
	git checkout -b "task-$1/$2"
fi
