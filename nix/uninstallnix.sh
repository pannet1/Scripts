#!/bin/sh

for i in {01..10}; do
  userdel "nixbld$i"
done
groupdel nixbld
