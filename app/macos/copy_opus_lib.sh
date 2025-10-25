#!/bin/bash
# Copy Opus library to app bundle

OPUS_LIB_SOURCE="${SRCROOT}/Frameworks/libopus.dylib"
OPUS_LIB_DEST="${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}/libopus.dylib"

if [ -f "$OPUS_LIB_SOURCE" ]; then
    echo "Copying Opus library from: $OPUS_LIB_SOURCE"
    echo "Copying Opus library to: $OPUS_LIB_DEST"
    mkdir -p "${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}"
    cp "$OPUS_LIB_SOURCE" "$OPUS_LIB_DEST"
    echo "Opus library copied successfully"
else
    echo "Warning: Opus library not found at: $OPUS_LIB_SOURCE"
    exit 1
fi
