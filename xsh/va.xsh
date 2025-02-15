#!/bin/env xonsh
#
print($ARGS)
if len($ARGS) < 2:
	print("no venv supplied")
	exit 
vox activate @($ARGS[1:])
