#!/bin/sh
set -e
cd $(dirname "$0")
#set -x

cd ..
TAG=$(date "+%Y-%m-%d--%H-%M")
git tag $TAG
git push origin $TAG
