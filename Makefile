APP_NAME  = Machlif
BUNDLE_ID = com.thezemah.machlif
CONFIG    = release
BUILD_DIR = .build
APP_DIR   = $(BUILD_DIR)/$(APP_NAME).app
INSTALL_DIR = /Applications
VERSION   = $(shell /usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist 2>/dev/null || echo "1.0")
DMG       = $(BUILD_DIR)/$(APP_NAME)-$(VERSION).dmg

.PHONY: all build app run install dmg test clean

all: app

build:
	swift build -c $(CONFIG)

app: build
	@rm -rf "$(APP_DIR)"
	@mkdir -p "$(APP_DIR)/Contents/MacOS"
	@mkdir -p "$(APP_DIR)/Contents/Resources"
	@cp Resources/Info.plist "$(APP_DIR)/Contents/Info.plist"
	@cp Resources/Machlif.icns "$(APP_DIR)/Contents/Resources/Machlif.icns"
	@cp "$$(swift build -c $(CONFIG) --show-bin-path)/$(APP_NAME)" "$(APP_DIR)/Contents/MacOS/$(APP_NAME)"
	@codesign --force --deep --sign - "$(APP_DIR)"
	@echo "Built $(APP_DIR)"

dmg: app
	@bash make_dmg.sh

run: app
	@open "$(APP_DIR)"

install: app
	@rm -rf "$(INSTALL_DIR)/$(APP_NAME).app"
	@cp -R "$(APP_DIR)" "$(INSTALL_DIR)/$(APP_NAME).app"
	@echo "Installed to $(INSTALL_DIR)/$(APP_NAME).app"

test:
	swift test

clean:
	swift package clean
	rm -rf "$(BUILD_DIR)/$(APP_NAME).app" "$(BUILD_DIR)"/*.dmg
