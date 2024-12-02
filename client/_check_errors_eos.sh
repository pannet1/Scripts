#!/bin/sh
"echo check failed systemctl services"
systemctl --failed
"echo check errors in log files"
journalctl -p 3 -xb

