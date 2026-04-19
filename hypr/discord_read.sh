#!/usr/bin/env bash


wl-paste  | piper-tts --model ~/.local/share/piper/voices/en_US-amy-medium.onnx --output-raw | \
  pw-cat --playback --raw --rate 22050 --channels 1 --format s16 --target=piper_sink -
