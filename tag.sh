#!/usr/bin/env bash

CONTAINER_NAME="${1:-willprice/nvidia-ffmpeg}"; shift

FFMPEG_VERSION="$(docker run --runtime=nvidia \
                            --rm \
                            -it  \
                            $CONTAINER_NAME \
                            ffmpeg -version  \
                | head -n1 \
                | awk '{ print $3 }')"
docker tag \
    "${CONTAINER_NAME}:latest" \
    "${CONTAINER_NAME}:$FFMPEG_VERSION" >&2
echo "$FFMPEG_VERSION"
