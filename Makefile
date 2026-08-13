PROJECT      := Agore.xcodeproj
SCHEME       := Agore
DESTINATION  := platform=macOS
DERIVED_DATA := build/DerivedData
CONFIGURATION ?= Debug
APP          := $(DERIVED_DATA)/Build/Products/$(CONFIGURATION)/Agore.app

XCODEBUILD := xcodebuild \
	-project $(PROJECT) \
	-scheme $(SCHEME) \
	-destination '$(DESTINATION)' \
	-configuration $(CONFIGURATION) \
	-derivedDataPath $(DERIVED_DATA)

.PHONY: all build test run clean gen-project icons

all: build

build:
	$(XCODEBUILD) build

test:
	$(XCODEBUILD) test

run: build
	@killall Agore >/dev/null 2>&1 || true
	@sleep 0.3
	open "$(APP)"
	@echo ""
	@echo "First launch opens a window; close it and Agore lives in the menu bar."
	@echo "Left-click the pixel person to show the plaza, right-click for Always on Top."

icons:
	python3 Scripts/generate_icons.py

clean:
	rm -rf build
	$(XCODEBUILD) clean || true

gen-project:
	python3 Scripts/gen_pbxproj.py
