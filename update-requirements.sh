#!/bin/bash

# Download the requirements.txt file with pinned fontc version and SHA256 hashes
# as specified in the 'VERSION' file.

FONTC_REPO_URL="https://github.com/googlefonts/fontc"

curl -LJo fontcExport.glyphsFileFormat/Contents/Resources/requirements.txt $FONTC_REPO_URL/releases/download/fontc-v$(<FONTC_VERSION)/requirements.txt
