#!/bin/bash

if ! command -v kasa; then
    pip install python-kasa
fi

kasa --host 192.168.1.225 off
kasa --host 192.168.1.225 on
