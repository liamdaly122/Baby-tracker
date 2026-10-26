#!/bin/sh
# Generates MissionControl.xcodeproj from project.yml. Needs XcodeGen (brew install xcodegen).
set -eu
cd "$(dirname "$0")/.."
xcodegen generate --spec project.yml
