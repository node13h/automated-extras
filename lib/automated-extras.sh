#!/usr/bin/env bash

# MIT license
# Copyright 2017 Sergej Alikov <sergej.alikov@gmail.com>

supported_automated_versions 0.2


supported_automated_extras_versions () {
    if ! semver_matches_one_of "${AUTOMATED_EXTRAS_VERSION}" "$@"; then
        throw "Unsupported version ${AUTOMATED_EXTRAS_VERSION} of Automated Extras detected. Supported versions are: $(joined ', ' "${@}")"
    fi
}
