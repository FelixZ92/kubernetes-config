#!/usr/bin/env bash

# $1: namespace
# $2: filename
# $3
#
#

if command -v gopass > /dev/null 2>&1; then
  PASSWORDSTORE_BINARY=gopass
elif command -v pass > /dev/null 2>&1; then
  PASSWORDSTORE_BINARY=pass
fi


