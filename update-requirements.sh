#!/bin/bash

# Download the requirements.txt file with pinned fontc version and SHA256 hashes
# as specified in the 'VERSION' file.

# Un-comment this and delete the fork's url when the upstream repo starts publishing releases
# FONTC_REPO_URL="https://github.com/googlefonts/fontc"
FONTC_REPO_URL="https://github.com/anthrotype/fontc"

curl -LJo fontcExport.glyphsFileFormat/Contents/Resources/requirements.txt $FONTC_REPO_URL/releases/download/fontc-v$(<FONTC_VERSION)/requirements.txt
