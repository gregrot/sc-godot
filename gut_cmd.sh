#!/usr/bin/env bash
set -euo pipefail
PROJECT_PATH="$(cd "$(dirname "$0")" && pwd)"
"${PROJECT_PATH}/.bin/Godot_v4.5-stable_linux.x86_64" --headless --path "${PROJECT_PATH}" --quit --script "res://addons/gut/gut_cmdln.gd" -gdir=res://test/unit -gexit -glog=2
