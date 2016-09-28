#!/bin/bash

if [ -n "$PROXY" ]; then
    PROXY_CMD="--proxy=$PROXY"
    echo "Using proxy $PROXY"
else
    PROXY_CMD=""
fi

# Launch the lmc composer demo
cd /root/lmc-composer-demo
PYTHONPATH=./src/ ./src/sbin/lmc-web-composer --debug --ks-template=./share/composer-template.ks --lorax-templates=./share/ $PROXY_CMD
