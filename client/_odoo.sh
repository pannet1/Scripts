#!/bin/env bash

systemctl start docker
docker start db
docker start -a odoo
