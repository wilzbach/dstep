#!/bin/bash

set -ex

app_name="dstep"

function configure {
  os=$(os)

  if [ "$os" = 'macos' ]; then
    ./configure --statically-link-clang
  elif [ "$os" = 'linux' ]; then
    ./configure --statically-link-binary
  elif [ "$os" = 'freebsd' ]; then
    ./configure --statically-link-binary
  else
    echo "Platform not supported: $os"
    exit 1
  fi
}

function build {
  dub build -b release
  strip "$app_name"
}

function test_dstep {
  dub -b test:functional
}

function version {
  git describe --tags
}

function arch {
  uname -m
}

function os {
  os=$(uname | tr '[:upper:]' '[:lower:]')
  [ $os = 'darwin' ] && echo 'macos' || echo $os
}

function release_name {
  echo "$app_name-$(version)-$(os)-$(arch)"
}

function archive {
  tar Jcf "$(release_name)".tar.xz "bin/$app_name"
}

configure
build
test_dstep
archive
