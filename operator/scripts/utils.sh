#!/bin/bash

function list_all_go_dirs {
  go list -f '{{.Dir}}' "${OPERATOR_DIR}/..."
}

function check_gomod {
  # For now there is no `-check` flag that would tell us if there is something
  # that needs to be updated with `go.mod` or `go.sum`. Therefore, we can just
  # run tidy and check if anything has changed in the files.
  # See: https://github.com/golang/go/issues/27005.
  if ! command -v git &>/dev/null; then
    return
  fi

  go mod tidy &>/dev/null
  if ! git diff --exit-code -- go.mod go.sum &>/dev/null; then
    printf "\nproject requires to run 'go mod tidy'\n"
    exit 1
  fi
}

function check_files_headers {
  for f in $(find ${OPERATOR_DIR} -type f -name "*.go" ! -regex $EXTERNAL_SRC_REGEX); do
    # Expect '// +build ...' or '// Package ...'.
    out=$(head -n 1 $f | grep -P "\/\/\s(\+build(.*)|Package(.*))")
    if [[ $? -ne 0 ]]; then
      echo "$f: first line should be package a description. Instead got:"
      head -n 1 $f
      exit 1
    fi

    # Expect '// no-copyright' or standard copyright preamble.
    out=$(head -n 10 $f | grep -P "((.*)\/\/\sno-copyright(.*)|(.*)Copyright(.*)NVIDIA(.*)All rights reserved(.*))")
    if [[ $? -ne 0 ]]; then
      echo "$f: copyright statement not found in first 10 lines. Use no-copyright to skip"
      exit 1
    fi
  done
}

function check_imports {
  # Check if `import` block contains more than one empty line.
  for f in $(find ${OPERATOR_DIR} -type f -name "*.go" ! -regex $EXTERNAL_SRC_REGEX); do
    # https://regexr.com/55u6r
    out=$(head -n 50 $f | grep -Pz 'import \((.|\n)*(\n\n)+(\t(\w|\.)?\s?(.*)"(.*)"\n)*\n+(\t(\w|\.)?\s?"(.*)"\n)*\)')
    if [[ $? -eq 0 ]]; then
      echo "$f: 'import' block contains (at least) 2 empty lines (expected: 1)"
      exit 1
    fi
  done
}

function perror {
  err_count=$(echo "$2" | sort -n | uniq | wc -l)
  if [[ -n $2 ]]; then
    echo "${2}" >&2
    echo "$1: ${err_count} failed" >&2
    exit 1
  fi
  exit 0
}
