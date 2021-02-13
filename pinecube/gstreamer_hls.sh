#!/bin/bash

set -e

# Quick and dirty gstreamer script that serves video over HLS
# Uses the S3's Cedar H264 encoder for hardware accelerated re-encoding.
# Loosely ased off of a sample config on the Pine64 wiki:
# https://wiki.pine64.org/wiki/PineCube#gstreamer:_h264_HLS

# Armbian camera support on the Pinecube currently requires the Ubuntu build. 
# Also equires a compiled copy of gst-plugin-cedar (https://github.com/gtalusan/gst-plugin-cedar),
# and the following Debian packages:
# v4l-utils gstreamer1.0-x gstreamer1.0-tools gstreamer1.0-plugins-base gstreamer1.0-plugins-good
# gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly gstreamer1.0-libav

# To compile gst-plugin-cedar, install:
# git build-essential dh-autoreconf libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev
# Then run:
# git clone https://github.com/gtalusan/gst-plugin-cedar.git
# cd gst-plugin-cedar
# ./autogen.sh
# make
# make install

mkdir /dev/shm/hls/

media-ctl --set-v4l2 '"ov5640 1-003c":0[fmt:UYVY8_2X8/1920x1080@1/15]' \
&& cd /dev/shm/hls/ \
&& gst-launch-1.0 --gst-debug-level=3 --gst-plugin-path=/usr/local/lib/gstreamer-1.0 -ve v4l2src device=/dev/video0 \
! video/x-raw,width=1920,height=1080,format=NV12,framerate=15/1 \
! cedar_h264enc ! mpegtsmux ! hlssink target-duration=1 playlist-length=2 max-files=3 &

python3 -m http.server