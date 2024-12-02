#!/bin/xonsh

# Check if the number of arguments is more than one
if len($ARGS) > 1:
    # Extract sublist starting from the second item
    sublist = $ARGS[1:]
    for item in sublist:
      pip install @(item)
else:
  print("argument is missing")
