#!/bin/sh

set -eu

cd "$(dirname "$0")"
. ./build_defines.sh

flutter build appbundle $DEFINES

open build/app/outputs/bundle/release
