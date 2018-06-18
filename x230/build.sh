#!/bin/bash
rm -rf build
cd ..
./build.sh -c $(ls -1 x230/config-* | cut -c 13-22) x230
