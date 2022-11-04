#!/usr/bin/env bash

_PX_FACE_DETECTION_MODEL=cnn
_PX_FACE_DETECTION_CPUS=-1
_PX_FACE_DETECTION_PARALLEL_JOBS=$(nproc --all || echo 1)

__detect_faces(){
    # prints images in $__known_faces_dir
    # that contain a detectable face
    # in sorted order
    exiftool \
        -ext jpg -ext jpeg -ext png \
        -m -s -S -q -q -r \
        -p '${directory}/${filename}' \
        "${__known_faces_dir:?not set}" \
    | parallel --progress \
        -j $_PX_FACE_DETECTION_PARALLEL_JOBS \
        -n 1 face_detection \
            --cpus $_PX_FACE_DETECTION_CPUS \
            --model $_PX_FACE_DETECTION_MODEL \
    | cut -d, -f1 \
    | sort
}

__rm_unusable(){
    comm -23 \
        <(
            exiftool \
                -ext jpg -ext jpeg -ext png \
                -m -s -S -q -q -r \
                -p '${directory}/${filename}' \
                "${__known_faces_dir:?not set}" \
            | sort
        ) \
        <(__detect_faces) \
    | parallel -j 1 _px_run rm -v
}

_px_cmd_refine_known_faces(){
    local _px_cmd_usage=(
        "$PROGRAM $COMMAND:"
        "   runs ageitgey/face_recognition (face_detection) on a directory of"
        "   known faces and removes images with no detected faces"
        ""
        "usage: $PROGRAM $COMMAND [options] KNOWN_FACES_DIR"
        ""
        "options:"
        "    -h           help"
        "    -d           dry run"
        "    -m cnn|hog   face_detection --model [default: $_PX_FACE_DETECTION_MODEL]"
        "    -c INT       face_detection --cpus [default: $_PX_FACE_DETECTION_CPUS]"
        "    -j INT       number of parallel face_detection jobs to launch [default: $_PX_FACE_DETECTION_PARALLEL_JOBS]"
    )

    local OPTIND OPTARG _opts
    while getopts ":hdm:c:j:" _opts; do
        case $_opts in
            h)
                _message "${_px_cmd_usage[@]}"
                return 0
                ;;
            d)
                __px_dryrun=true
                ;;
            m)
                _PX_FACE_DETECTION_MODEL=$OPTARG
                ;;
            c)
                _PX_FACE_DETECTION_CPUS=$OPTARG
                ;;
            j)
                _PX_FACE_DETECTION_PARALLEL_JOBS=$OPTARG
                ;;
            *)
                _warn "invalid option: -$OPTARG"
                _warn "${_px_cmd_usage[@]}"
                return 1
                ;;
        esac
    done
    shift $((OPTIND-1))

    local __known_faces_dir="${1:?KNOWN_FACES_DIR not set}"
    __rm_unusable
}

_px_cmd_refine_known_faces "$@"
