#!/usr/bin/env bash

set -euo pipefail

BASE_URL="https://binaries.soliditylang.org/bin"
REPO_ROOT="$(dirname "$0")/.."
LIST_FILE=/tmp/list.json

function fail() {
    echo -e "ERROR: $@" >&2
    exit 1
}

function check_release_version() {
    current_version=$1

    curl --silent --fail "$BASE_URL/list.json" -o $LIST_FILE
    [[ ! -f $LIST_FILE ]] && fail "Download of release list failed:\n    [url]: $BASE_URL/list.json"

    # Retrieve the latest released version
    latest_version=$(cat $LIST_FILE | jq --raw-output ".latestRelease")
    release_version=$(cat $LIST_FILE | jq --raw-output ".releases | .[\"$latest_version\"]" | sed --regexp-extended --quiet 's/^soljson-v(.*).js$/\1/p')

    # Check if current version is the latest release
    if [ $current_version != "$release_version" ]; then
        fail "Version is not the latest release:\n    [current]: $current_version\n    [latest]: $latest_version"
    fi

    current_sha=$(shasum --binary --algorithm 256 ./soljson.js | awk '{ print $1 }')
    release_sha=$(cat $LIST_FILE | jq --raw-output ".builds[] | select(.longVersion == \"$release_version\") | .sha256" | sed 's/^0x//')

    # Check if sha matches
    if [ "$current_sha" != "$release_sha" ]; then
        fail "Checksum mismatch.\n    [current]: $current_sha\n    [release]: $release_sha"
    fi
}

(
    cd "$REPO_ROOT"

    current_version=$(node ./dist/solc.js --version | sed --regexp-extended --quiet 's/^(.*).Emscripten.*/\1/p')

    # Verify if current version matches the package version.
    # It already exits with an error if the version mismatch
    node ./dist/verifyVersion.js

    # Verify if current version is the latest release
    check_release_version $current_version
    if [ $? -eq 0 ]; then
        echo "solc-js version $current_version is the latest release"
    fi

    # Cleanup temp files
    [[ -f $LIST_FILE ]] && rm -f $LIST_FILE
)
