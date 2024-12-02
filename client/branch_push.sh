#!/usr/bin/env bash
if [ -z "$1" ]; then
	echo "branch name is required"
else
	git add .
	if [ -z "$2" ]; then
		git commit -am "no comments"
	else
		git commit -am "$2"
	fi
	git push origin "$1"
fi
