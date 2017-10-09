#!/bin/bash

set -eu

LLVM_VERSION='4.0.0'

freebsd='freebsd'
darwin='darwin'
linux='linux'
debian='debian'
ubuntu='ubuntu'
fedora='fedora'
centos='centos'

function unsupported {
  echo "Unsupported operating system: $(uname -a)"
  exit 1
}

function operating_system {
  local os=$(uname | tr '[:upper:]' '[:lower:]')
  local nodename=$(uname -n | tr '[:upper:]' '[:lower:]')
  local kernel=$(uname -v | tr '[:upper:]' '[:lower:]')

  if [ "$os" = linux ]; then
    if [ "$nodename" = "$ubuntu" ] ||
       [ "$nodename" = "$debian" ] ||
       [ "$nodename" = "$fedora" ]; then
         echo "$nodename"
     else
       if echo "$kernel" | grep -i -q "$ubuntu"; then
         echo "$ubuntu"
       else
         unsupported
       fi
     fi
  elif [ "$os" = "$darwin" ] || [ "$os" = "$freebsd" ]; then
    echo "$os"
  else
    unsupported
  fi
}

function llvm_archive {
  local os=$(operating_system)
  local is_64bit=false

  if [ $(uname -m) = x86_64 ]; then
    is_64bit=true
  else
    is_64bit=false
  fi

  if [ "$os" = "$freebsd" ]; then
    if [ "$is_64bit" = true ]; then
      echo "clang+llvm-$LLVM_VERSION-amd64-unknown-freebsd10.tar.xz"
    else
      echo "clang+llvm-$LLVM_VERSION-i386-unknown-freebsd10.tar.xz"
    fi
  elif [ "$os" = "$darwin" ]; then
    if [ "$is_64bit" = true ]; then
      echo "clang+llvm-$LLVM_VERSION-x86_64-apple-darwin.tar.xz"
    else
      unsupported
    fi
  elif [ "$os" = "$ubuntu" ]; then
    if [ "$is_64bit" = true ]; then
      echo "clang+llvm-$LLVM_VERSION-x86_64-linux-gnu-ubuntu-14.04.tar.xz"
    else
      unsupported
    fi
  elif [ "$os" = "$fedora" ]; then
    if [ "$is_64bit" = true ]; then
      echo "clang+llvm-$LLVM_VERSION-x86_64-fedora23.tar.xz"
    else
      echo "clang+llvm-$LLVM_VERSION-i686-fedora23.tar.xz"
    fi
  else
    unsupported
  fi
}

function llvm_url {
  local archive=$(llvm_archive)
  echo "https://releases.llvm.org/$LLVM_VERSION/$archive"
}

function download_llvm {
  local archive_path="clangs/$(llvm_archive)"
  mkdir -p clangs

  if [ ! -f "$archive_path" ]; then
    curl -L -o "$archive_path" "$(llvm_url)"
  fi
}

function extract_archive {
  local archive=$(llvm_archive)
  mkdir -p clangs/clang
  tar xf "clangs/$archive" -C clangs/clang --strip-components=1
}

download_llvm
extract_archive
