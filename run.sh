#!/bin/sh 
killall -9 picaro
git pull
cmake --build build -j$(nproc)
build/picaro
