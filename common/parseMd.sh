#!/usr/bin/env bash
perl -ne 's#^!\[\[(.+?)\]\].*#`'$0' "$1"`#e;print' "$@"
