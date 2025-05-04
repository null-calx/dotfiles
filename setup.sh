#!/bin/bash

set -euo pipefail

current_directory=$(pwd)
config_directory="${current_directory}/config/"

resolve_target() {
    declare -r target_type="$1"
    declare -r target_input="$2"

    case "$target_type" in
	home)
	    base="${HOME}/"
	    ;;
	config)
	    base="${HOME}/.config/"
	    ;;
	git)
	    base="${HOME}/git/"
	    ;;
	projects)
	    base="${HOME}/projects/"
	    ;;
    esac

    if [[ -n "$target_input" ]]; then
	final_target="${base}${target_input}/"
    else
	final_target="${base}"
    fi

    echo "$final_target"
}

process_git_repo_block() {
    declare -r git_repo="$1"
    declare -r target_directory="$2"
    declare -r remote="$3"
    declare -r ensure_latest="$4"
    declare -r build_cmd="$5"
    declare -r symlinks="$6"

    mkdir -p "$target_directory"

    if [[ -d "${target_directory}.git" ]]; then
	echo "  checking remote url for ${target_directory}"
	remote_url=$(git -C "$target_directory" remote get-url "$remote")
	if [[ "$remote_url" != "$git_repo" ]]; then
	    echo "ERROR: remote_url: ${remote_url} didn't match intended url: ${git_repo}"
	    exit 1
	fi
    else
	echo "  cloning ${git_repo} into ${target_directory}"
	echo git clone "$git_repo" "$target_directory"
    fi

    if [[ "$ensure_latest" == "true" ]]; then
	echo "  pulling latest changes"
	echo git -C "$target_directory" pull "$remote"
    fi

    if [[ -n "$build_cmd" ]]; then
	echo "  building"
	pushd "$target_directory"
	echo bash -c "$build_cmd"
	popd
    fi

    if [[ -n "$symlinks" ]]; then
	echo "  creating symlinks"
	echo "$symlinks" | yq '.[] | @json' | while read -r block; do
	    name=$(echo "$block" | yq ".name")
	    base=$(echo "$block" | yq ".base")
	    dest=$(echo "$block" | yq '.dest // ""')
	    fold=$(echo "$block" | yq '.fold // ""')

	    config_directory="$target_directory" process_configuration_block "$name" "$(resolve_target "$base" "$fold")" "$dest"
	done
    fi
}

process_configuration_block() {
    declare -r source_filename="$1"
    declare -r target_directory="$2"
    declare -r target_filename="${3:-$source_filename}"

    source_full_filename="${config_directory}${source_filename}"
    target_full_filename="${target_directory}${target_filename}"

    mkdir -p "$target_directory"

    echo "  linking ${source_full_filename} <- ${target_full_filename}"
    ln -sf "$source_full_filename" "$target_full_filename"
}

yq '.gitRepoBlocks[] | @json' config.yaml | while read -r block; do
    tool_name=$(echo "$block" | yq ".tool")

    repo=$(echo "$block" | yq ".repo")
    base=$(echo "$block" | yq ".base")
    fold=$(echo "$block" | yq '.fold')

    remote=$(echo "$block" | yq '.remote // "origin"')
    ensure_latest=$(echo "$block" | yq '.ensure-latest // "false"')
    build_cmd=$(echo "$block" | yq '.build // ""')
    symlinks=$(echo "$block" | yq '.symlinks // ""')

    echo "configuring ${tool_name}"
    process_git_repo_block "$repo" "$(resolve_target "$base" "$fold")" "$remote" "$ensure_latest" "$build_cmd" "$symlinks"
    echo
done

yq '.configurationBlocks[] | @json' config.yaml | while read -r block; do
    tool_name=$(echo "$block" | yq ".tool")

    name=$(echo "$block" | yq ".name")
    base=$(echo "$block" | yq ".base")
    dest=$(echo "$block" | yq '.dest // ""')
    fold=$(echo "$block" | yq '.fold // ""')

    echo "configuring ${tool_name}"
    process_configuration_block "$name" "$(resolve_target "$base" "$fold")" "$dest"
    echo
done
