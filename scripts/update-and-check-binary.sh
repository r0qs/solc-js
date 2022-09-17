#!/usr/bin/env bash

BASE_URL="https://binaries.soliditylang.org/bin"
REPO_ROOT="$(dirname "$0")/.."

function fail() {
	echo -e "$@" >&2
	exit 1
}

function check_version() {
	current_version=$(node ./dist/solc.js --version | sed -En 's/^(.*).Emscripten.*/\1/p')

	# Retrieve the correspondent released version
	short_version=$(echo "${current_version}" | sed -En 's/^([0-9.]+).*\+commit\.[0-9a-f]+.*$/\1/p')
	release_version=$(curl -s "${BASE_URL}/list.json"  | jq ".releases | .[\"${short_version}\"]" | tr -d '"' | sed -En 's/^soljson-v(.*).js$/\1/p')

	# check if current version exists as release
	if [ "${current_version}" != "${release_version}" ]; then
		fail "Failed: version mismatch:\n [current]: ${current_version}\n [release]: ${release_version}"
	fi

	current_sha=$(shasum -b -a 256 ./soljson.js | awk '{ print $1 }')
	release_sha=$(curl -s "${BASE_URL}/list.json" | jq ".builds[] | select(.longVersion == \"${release_version}\") | .sha256" | tr -d '"' | sed 's/^0x//')

	# check if sha matches
	if [ "${current_sha}" != "${release_sha}" ]; then
		fail "Failed: checksum mismatch:\n [current]: ${current_sha}\n [release]: ${release_sha}"
	fi
}

(
	cd "${REPO_ROOT}"

	# Remove previous soljson.js binary if exists
	[[ -f soljson.js ]] && rm -f soljson.js

	# Update soljson.js binary
	npm run updateBinary
	npm run build

	# Check if current binary works
	echo "contract C {}" > C.sol
	node ./dist/solc.js C.sol --bin
	[[ ! -f C_sol_C.bin ]] && fail "Failed: downloaded binary is not working"
	rm -f C.sol C_sol_C.bin

	check_version
)