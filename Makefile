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

.PHONY: all build release test run run-release clean gen-project icons plaza plaza-down plaza-test

all: build

build:
	$(XCODEBUILD) build

release:
	$(MAKE) build CONFIGURATION=Release

test:
	$(XCODEBUILD) test

run: build
	@killall Agore >/dev/null 2>&1 || true
	@sleep 0.3
	open "$(APP)"
	@echo ""
	@echo "Built $(CONFIGURATION) → $(APP)"
	@echo "Menu bar icon: floating strip. Dock click or ⌘0: square window."
	@echo "Right-click the icon for Always on Top / token."

run-release:
	$(MAKE) run CONFIGURATION=Release

icons:
	python3 Scripts/generate_icons.py

clean:
	rm -rf build
	$(XCODEBUILD) clean || true

gen-project:
	python3 Scripts/gen_pbxproj.py

plaza:
	@test -f .env || (echo "Copy .env.example to .env and set AGORE_TOKEN first."; exit 1)
	bash Scripts/gen_tls.sh
	docker compose up --build -d
	@echo "Plaza HTTPS on https://127.0.0.1:8081  (self-signed, for Cloudflare)"
	@echo "Client URL: wss://agore.bytebar.dev/v1/plaza"
	@echo "Set the same token in the app: right-click → Plaza Token…"

plaza-down:
	docker compose down

plaza-test:
	cd server && go test ./...
