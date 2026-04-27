APP_NAME = Koe
BUNDLE_ID = com.yourname.koe
BUILD_PATH = .build/release
APP_BUNDLE = $(APP_NAME).app
CONTENTS = $(APP_BUNDLE)/Contents
MACOS = $(CONTENTS)/MacOS
RESOURCES = $(CONTENTS)/Resources

# Paths to Homebrew dependencies (common on Apple Silicon)
BREW_PREFIX = /opt/homebrew
LIB_WHISPER = $(BREW_PREFIX)/lib/libwhisper.1.dylib
LIB_GGML = $(BREW_PREFIX)/lib/libggml.0.dylib
LIB_GGML_BASE = $(BREW_PREFIX)/lib/libggml-base.0.dylib

.PHONY: all build bundle clean run

all: bundle

build:
	@echo "🔨 Building $(APP_NAME) in release mode..."
	swift build -c release --disable-sandbox

bundle: build
	@echo "📦 Creating $(APP_BUNDLE)..."
	@# Kill running instance so we can overwrite the binary
	@killall $(APP_NAME) 2>/dev/null || true
	@mkdir -p $(MACOS)
	@mkdir -p $(RESOURCES)
	
	@# Copy binary
	@cp $(BUILD_PATH)/$(APP_NAME) $(MACOS)/$(APP_NAME)
	
	@# Copy Info.plist
	@cp Sources/Koe/Resources/Info.plist $(CONTENTS)/Info.plist
	
	@# Copy Resources from build folder
	@cp -R $(BUILD_PATH)/Koe_Koe.bundle/* $(RESOURCES)/ 2>/dev/null || true
	
	@# Bundle dynamic libraries if they exist (Fixes "dyld: Library not loaded" error)
	@echo "📚 Bundling dynamic libraries..."
	@cp $(LIB_WHISPER) $(RESOURCES)/ 2>/dev/null || true
	@cp $(LIB_GGML) $(RESOURCES)/ 2>/dev/null || true
	@cp $(LIB_GGML_BASE) $(RESOURCES)/ 2>/dev/null || true
	
	@# Fix rpaths so whisper-cli looks for libs in the same folder
	@chmod +x $(RESOURCES)/whisper-cli
	@install_name_tool -add_rpath "@loader_path/." $(RESOURCES)/whisper-cli 2>/dev/null || true
	@install_name_tool -change "@rpath/libwhisper.1.dylib" "@loader_path/libwhisper.1.dylib" $(RESOURCES)/whisper-cli 2>/dev/null || true
	@install_name_tool -change "$(BREW_PREFIX)/opt/ggml/lib/libggml.0.dylib" "@loader_path/libggml.0.dylib" $(RESOURCES)/whisper-cli 2>/dev/null || true
	@install_name_tool -change "$(BREW_PREFIX)/opt/ggml/lib/libggml-base.0.dylib" "@loader_path/libggml-base.0.dylib" $(RESOURCES)/whisper-cli 2>/dev/null || true
	
	@echo "✅ $(APP_BUNDLE) created successfully."

run: bundle
	@open $(APP_BUNDLE)

clean:
	@rm -rf .build
	@rm -rf $(APP_BUNDLE)
	@echo "🧹 Cleaned."
