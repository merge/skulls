#!/bin/bash
cd ..
./build.sh --clean-slate --commit $(ls -1 x230/config-* | cut -c 13-22) x230
