#!/usr/bin/env bash

set -euo pipefail

build_deps() {
  os=''
  check_os os
  
  arch=''
  check_architecture arch
  
  config="${1-RelWithDebInfo}"
  
  # where are we?
  SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
  
  # add utils scripts for our platform to this file
  utils_folder="$SCRIPT_DIR/utils.$os"
  for util in "$utils_folder"/*
  do
    source "$util"
  done
  
  # add all dependency script files for our platform to this file
  deps_folder="$SCRIPT_DIR/deps.$os"
  echo $deps_folder
  dependencies=()
  for dependency in "$deps_folder"/*
  do
    source "$dependency"
    dependencies+=("$(basename "$dependency")")
  done
  
  mkdir -p "build_temp"
  mkdir -p "ares-deps"
  mkdir -p "ares-deps-source/src"
  cd "build_temp"
  echo "{ \"build_host_working_directory\": \"$(pwd)\" }" > ../ares-deps-source/buildhost.json
  for dependency in "${dependencies[@]}"
  do
    # set up the dependency
    setup_func="${dependency}_setup"
    $setup_func
    
    # if we have a patch, patch the dependency
    patch_func="${dependency}_patch"
    $patch_func

    # package the source code for debugging
    patch_func="${dependency}_package_source"
    $patch_func

    # build the dependency
    build_func="${dependency}_build"
    $build_func
  done
  cd ..

  # remove git repository directories for packaged sources
  find ares-deps-source/src -type d -name ".git" -exec rm -rf {} +

  mkdir -p "ares-deps"
  for dependency in "${dependencies[@]}"
  do
    # install the dependency
    install_func="${dependency}_install"
    $install_func
  done
  cd ..
  echo "artifactName=ares-deps-$os-$arch" >> $GITHUB_OUTPUT
}

check_os() {
  if [ "$(uname)" == "Darwin" ]; then
    eval "$1='macos'"
  elif [ "$(uname)" == "Linux" ]; then
    eval "$1='linux'"
  else
    eval "$1='windows'"
  fi
}

check_architecture() {
  if [ "$(uname)" == "Darwin" ]; then
    eval "$1='universal'"
  elif [ "$(uname)" == "Linux" ]; then
    eval "$1='universal'"
  else
    local unametest=$(uname -a)
    echo $unametest
    local unameout=$(uname -p)
    eval "$1=$unameout"
  fi
}

build_deps "${@}"
