#!/bin/bash
# Create a symlink so that the local package reference ../../ManagedNavigation
# resolves correctly on Xcode Cloud, where the repo is cloned into
# /Volumes/workspace/repository/ instead of /Volumes/workspace/ManagedNavigation/
ln -sf "$CI_PRIMARY_REPOSITORY_PATH" "$CI_PRIMARY_REPOSITORY_PATH/../ManagedNavigation"
