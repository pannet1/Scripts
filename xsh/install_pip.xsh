#!/bin/xonsh

# Check if the number of arguments is more than one
if len($ARGS) > 1:
    lst = $ARGS
    grep -rw lst[0] -e lst[1]
else:
  print("usage is '/search/dir/' 'pattern'")
