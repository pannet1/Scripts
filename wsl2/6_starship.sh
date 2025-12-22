#!/bin/bash

curl -sS https://starship.rs/install.sh | sh

# We use a backslash \" to tell the script: "Put a literal quote here"
LINE="eval \"\$(starship init bash)\""

if grep -Fxq "$LINE" ~/.bashrc; then
  echo "Already exists."
else
  echo "$LINE" >>~/.bashrc
  echo "Added successfully!"
fi
