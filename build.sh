#!/usr/bin/env bash
set -e
set -o pipefail

usage() {
    echo """Usage: $(basename $0) [-h] [-v] [IMAGE]

optional arguments:
    -h, --help              show this help message and exit
    -v, --verbose           enable verbose logging"""
    exit 1
}

log() {
    if [[ "$VERBOSE" == true ]]; then
        echo "$@"
    fi
}

argparse() {
    IMAGE=""
    VERBOSE=false

    while [[ "$#" -gt 0 ]]; do
        case $1 in
            -h|--help) usage ;;
            -i|--image) IMAGE="$2"; shift ;;
            -v|--verbose) VERBOSE=true; ;;
            *) positional "$1";;
        esac
        shift
    done

    validate_args

    export VERBOSE
    export IMAGE
    export -f log
}

positional() {
    if [[ -z "$IMAGE" ]]; then
        IMAGE="$1"
    else
        echo "Unknown parameter passed: $1"
        exit 1
    fi
}

validate_args() {
    if [[ -z "$IMAGE" ]]; then
        echo "Parameter IMAGE required"
        exit 0
    fi
    if [[ -e "sources/$IMAGE.json" ]]; then
        log "Image source for $IMAGE found"
    else
        echo "Cannot find image $IMAGE"
        exit 1
    fi
}

process_json() {
    NAME="$(jq -r '.["name"]' sources/$IMAGE.json)"
    URL="$(jq -r '.["url"]' sources/$IMAGE.json)"
}

get_image() {
    mkdir -p cache
    mkdir -p work

    if [[ -e "cache/$NAME.img" ]]; then
        log "Pulling $NAME image from cache"
        cp "cache/$NAME.img" "work/$NAME.img"
    else
        log "Image not found, downloading..."
        download_image
    fi
}

download_image() {
    curl -L -o "work/$NAME" "$URL"
    if [[ "$(xdg-mime query filetype work/$NAME)" == "application/zip" ]]; then
        mkdir -p work/temp
        log "File is zip. Unzipping..."
        7z x "work/$NAME" -o"work/temp/"
        if [[ "$(ls -1 work/temp | wc -l)" != "1" ]]; then # TODO: handle multiple files from zip
            echo "Cannot handle more than one file in output, quitting..."
        fi
        mv work/temp/* "work/$NAME"
        rm -rf work/temp
    fi
    if [[ "$(xdg-mime query filetype work/$NAME)" != "application/octet-stream" ]]; then
        echo "Unknown image type, quitting..."
    fi
    if [[ "$NAME" != *".img"* ]]; then
        mv "work/$NAME" "work/$NAME.img"
    fi
    cp "work/$NAME.img" "cache/$NAME.img"
}

argparse $@
process_json
get_image
