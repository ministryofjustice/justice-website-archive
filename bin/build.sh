#!/usr/bin/env bash

### Node server
echo -e "${DOTS} ${DOTS} Grabbing dependencies for node... ${DOTS}\n"

cd ./conf/node/ || exit
npm install
