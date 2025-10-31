#!/bin/bash
# Copy llama.cpp native libraries to app bundle

SOURCE_DIR="${SRCROOT}/Runner/Resources/Frameworks"
DEST_DIR="${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/Contents/Frameworks"

mkdir -p "$DEST_DIR"

echo "Copying llama.cpp libraries..."
cp -f "${SOURCE_DIR}"/*.dylib "$DEST_DIR/" || exit 1

echo "Updating library install names..."
cd "$DEST_DIR"

# Fix library dependencies
for lib in *.dylib; do
    echo "Processing $lib"
    install_name_tool -id "@rpath/$lib" "$lib"
    
    # Update dependencies to use @rpath
    otool -L "$lib" | grep "libggml\|libllama\|libmtmd" | awk '{print $1}' | while read dep; do
        depname=$(basename "$dep")
        echo "  Updating dependency: $depname"
        install_name_tool -change "$dep" "@rpath/$depname" "$lib" || true
    done
done

echo "llama.cpp libraries copied successfully"
