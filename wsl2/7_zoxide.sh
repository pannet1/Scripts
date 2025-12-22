#!/bin/bash

curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh

# Define the line to add
LINE="eval \"\$(zoxide init bash)\""
# Check if the line already exists to avoid duplicates
if grep -Fxq "$LINE" ~/.bashrc; then
  echo "Zoxide is already configured in .bashrc"
else
  # Append the line to the end of the file
  echo "$LINE" >>~/.bashrc
  echo "Successfully added Zoxide to .bashrc"

  # Refresh the current shell session
  source ~/.bashrc
  echo "Shell refreshed. You can now use 'z' instead of 'cd'!"
fi
