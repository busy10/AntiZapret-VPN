#!/bin/bash

cd /root/antizapret/
screen -dmS proxy2 bash -c "python3 proxy2.py"
python3 proxy1.py
