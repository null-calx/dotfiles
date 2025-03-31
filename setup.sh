#!/bin/sh

set -euo pipefail

current_directory=$(pwd)
config_directory="${current_directory}/config/"

user_home="$HOME/"
config_home="$HOME/.config/"

process_block() {
    declare -r tool_name="$1"
    declare -r config_filename="$2"
    declare -r destination_type="$3"
    declare -r destination_name="${4:-$config_filename}"
    declare -r destination_dir_input="$5"

    echo "configuring ${tool_name}"

    source_filename="${config_directory}${config_filename}"

    case "$destination_type" in
	home)
	    config_dir="${user_home}"
	    ;;
	config)
	    config_dir="${config_home}"
	    ;;
    esac

    if [[ -n "$destination_dir_input" ]]; then
	local destination_dir="${config_dir}${destination_dir_input}/"
    else
	local destination_dir="${config_dir}"
    fi

    destination_filename="${destination_dir}${destination_name}"

    echo "  making directories ${destination_dir}"
    mkdir -p "$destination_dir"

    echo "  linking ${source_filename} to ${destination_filename}"
    ln -sf "$source_filename" "$destination_filename"

    echo
}

yq '.configurationBlocks[] | @json' config.yaml | while read -r block; do
    tool=$(echo "$block" | yq .tool)
    name=$(echo "$block" | yq .name)
    base=$(echo "$block" | yq .base)
    dest=$(echo "$block" | yq '.dest // ""')
    fold=$(echo "$block" | yq '.fold // ""')

    process_block "$tool" "$name" "$base" "$dest" "$fold"
done
