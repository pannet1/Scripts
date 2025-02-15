#!/usr/bin/env bash

# Get the current working directory
current_directory=$(pwd)
# Extract the directory name
directory_name=$(basename "$current_directory")

if [ -z "$1" ]; then
	echo "You need to provide the repo name."
	exit 1
fi

# Compare the current directory name with the first argument
if [ "$directory_name" != "$1" ]; then
	echo "The current directory name '$directory_name' is not equal to '$1'."
else
	cp ~/Scripts/client/.gitignore . -uv
	cp ~/Scripts/client/requirements.txt . -uv
	git init
	git add .
	git commit -am "first commit"
	git remote add origin "https://gitlab.com/pannet12/$1.git"
	git branch -M main
	git push -u origin main
fi
