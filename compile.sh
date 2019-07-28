#!/usr/bin/env bash

SELFDIR=$(cd $(dirname "$0");pwd)

export GOPATH="${SELFDIR}"

if [[ ${OS} =~ ^Windows.*$ ]]; then
    cd "${GOPATH}/src/json" && go build -o "$GOPATH/json.exe"
else
    cd "${GOPATH}/src/json" && go build -o "$GOPATH/json"
fi

exit    $?

