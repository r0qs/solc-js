#!/usr/bin/env bash

set -euo pipefail

BASE_URL="https://binaries.soliditylang.org/bin"
REPO_ROOT="$(dirname "$0")/.."
LIST_FILE=/tmp/list.json

function fail() {
    echo -e "ERROR: $@" >&2
    exit 1
}

function check_version() {
    current_version=$1

    curl --silent --fail "$BASE_URL/list.json" -o $LIST_FILE
    [[ ! -f $LIST_FILE ]] && fail "download of release list failed:\n    [url]: $BASE_URL/list.json"

    # Retrieve the latest released version
    latest_version=$(cat $LIST_FILE | jq --raw-output ".latestRelease")
    release_version=$(cat $LIST_FILE | jq --raw-output ".releases | .[\"$latest_version\"]" | sed -En 's/^soljson-v(.*).js$/\1/p')

    # check if current version is the latest release
    if [ $current_version != "$release_version" ]; then
        fail "version is not the latest release:\n    [current]: $current_version\n    [latest]: $latest_version"
    fi

    current_sha=$(shasum -b -a 256 ./soljson.js | awk '{ print $1 }')
    release_sha=$(cat $LIST_FILE | jq --raw-output ".builds[] | select(.longVersion == \"$release_version\") | .sha256" | sed 's/^0x//')

	# check if sha matches
	if [ "${current_sha}" != "${release_sha}" ]; then
		fail "ERROR: Checksum mismatch.\n [current]: ${current_sha}\n [release]: ${release_sha}"
	fi

    # check if the current version is the latest release
    latest_version=$(cat $LIST_FILE | jq --raw-output ".latestRelease")
    if [ "$short_version" != "$latest_version" ]; then
        fail "version is not the latest release:\n    [current]: $short_version\n    [latest]: $latest_version"
    fi
}

(
    cd "$REPO_ROOT"

    current_version=$(node ./dist/solc.js --version | sed -En 's/^(.*).Emscripten.*/\1/p')
    check_version $current_version
    if [ $? -eq 0 ]; then
        echo "solc-js version $current_version is the latest release"
    fi

    # cleanup temp files
    [[ -f $LIST_FILE ]] && rm -f $LIST_FILE
)
