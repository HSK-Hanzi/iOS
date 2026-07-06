#!/bin/sh

# Xcode Cloud runs this right after cloning the repository, before resolving packages or building.

set -eu

# Swift macros (SwiftData's @Model, Observation's @Observable) fail fingerprint validation on
# Xcode Cloud because it doesn't persist macro approvals between builds.
defaults write com.apple.dt.Xcode IDESkipMacroFingerprintValidation -bool YES

# The build's "Copy Data Resources" phase reads the open language data (Git LFS plists) from the
# Data/Open submodule. It's declared as an SSH submodule; rewrite it to anonymous HTTPS and pull
# just that one. Data/Proprietary stays absent — the build falls back to open-only data — so the
# archive never needs a deploy key, matching the project's open-only CI rule.
git config --global url."https://github.com/".insteadOf "git@github.com:"
git -C "$CI_PRIMARY_REPOSITORY_PATH" submodule update --init Data/Open
git -C "$CI_PRIMARY_REPOSITORY_PATH/Data/Open" lfs pull

# Install sentry-cli so the archive's "Upload Debug Symbols to Sentry" build phase can symbolicate
# production crashes. It authenticates with SENTRY_AUTH_TOKEN, set as a secret environment variable
# on the Xcode Cloud workflow.
curl -sL https://sentry.io/get-cli/ | bash
