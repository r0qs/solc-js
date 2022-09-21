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
    curl --silent --fail "$BASE_URL/list.json" -o $LIST_FILE
    [[ ! -f $LIST_FILE ]] && fail "download of release list failed:\n    [url]: $BASE_URL/list.json"

    current_version=$(node ./dist/solc.js --version | sed -En 's/^(.*).Emscripten.*/\1/p')

    # Retrieve the correspondent released version
    short_version=$(echo "$current_version" | sed -En 's/^([0-9.]+).*\+commit\.[0-9a-f]+.*$/\1/p')
    release_version=$(cat $LIST_FILE | jq --raw-output ".releases | .[\"$short_version\"]" | sed -En 's/^soljson-v(.*).js$/\1/p')

    # check if current version exists as release
    if [ $current_version != "$release_version" ]; then
        fail "version mismatch:\n    [current]: $current_version\n    [release]: $release_version"
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

    # Remove previous soljson.js binary if exists
    [[ -f soljson.js ]] && rm -f soljson.js

    # Update soljson.js binary
    npm run updateBinary
    npm run build

    check_version

    # cleanup
    [[ -f $LIST_FILE ]] && rm -f $LIST_FILE
)
