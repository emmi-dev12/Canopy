# Canopy — macOS Menubar Search & Organizer
# ──────────────────────────────────────────────────────────────────────────────
#
#   make install     Build and install Canopy to /Applications   ← start here
#   make run         Build and launch without installing
#   make open        Open the already-installed app
#   make uninstall   Remove from /Applications
#   make clean       Delete build artefacts
#
# Requirements: Xcode 15+ installed (not just Command Line Tools)
# ──────────────────────────────────────────────────────────────────────────────

.PHONY: all build install uninstall clean run open check-xcode

APP       := Canopy
PROJECT   := Canopy.xcodeproj
SCHEME    := Canopy
CONFIG    := Release
BUILD_DIR := .build
PRODUCT   := $(BUILD_DIR)/Build/Products/$(CONFIG)/$(APP).app
DEST      := /Applications/$(APP).app

# Use xcpretty for readable output if it's available, otherwise raw xcodebuild
XCPRETTY  := $(shell command -v xcpretty 2>/dev/null)
ifdef XCPRETTY
  FORMAT = | xcpretty
else
  FORMAT =
endif

# ── Default ────────────────────────────────────────────────────────────────────
all: install

# ── Preflight check ────────────────────────────────────────────────────────────
check-xcode:
	@if ! command -v xcodebuild &>/dev/null; then \
		echo ""; \
		echo "  ✗  Xcode not found."; \
		echo "     Install Xcode from the App Store, then re-run make install."; \
		echo ""; \
		exit 1; \
	fi
	@XCODE_VER=$$(xcodebuild -version 2>/dev/null | head -1 | awk '{print $$2}' | cut -d. -f1); \
	if [ "$$XCODE_VER" -lt 15 ] 2>/dev/null; then \
		echo "  ✗  Xcode $$XCODE_VER found, but Xcode 15+ is required."; \
		exit 1; \
	fi

# ── Build ──────────────────────────────────────────────────────────────────────
build: check-xcode
	@echo ""
	@echo "  Building $(APP) ($(CONFIG))..."
	@echo ""
	@set -o pipefail; \
	xcodebuild \
		-project "$(PROJECT)" \
		-scheme  "$(SCHEME)" \
		-configuration "$(CONFIG)" \
		-derivedDataPath "$(BUILD_DIR)" \
		CODE_SIGN_IDENTITY="" \
		CODE_SIGNING_REQUIRED=NO \
		CODE_SIGNING_ALLOWED=NO \
		DEVELOPMENT_TEAM="" \
		build $(FORMAT)

# ── Install ────────────────────────────────────────────────────────────────────
# Builds the app, copies it to /Applications, and applies an ad-hoc signature.
#
# Ad-hoc signing (codesign -s -) is sufficient for local personal use.
# To distribute or notarize, sign with a real Apple Developer certificate instead.
install: build
	@echo ""
	@echo "  Installing $(APP) → /Applications..."
	@rm -rf "$(DEST)"
	@cp -R "$(PRODUCT)" "$(DEST)"
	@codesign --force --deep --sign - "$(DEST)"
	@echo ""
	@echo "  ┌─────────────────────────────────────────────────────┐"
	@echo "  │  ✓  Canopy.app installed to /Applications           │"
	@echo "  │                                                      │"
	@echo "  │  First-launch checklist:                            │"
	@echo "  │   1. Launch Canopy from Launchpad (or: make open)   │"
	@echo "  │   2. System Settings → Privacy & Security           │"
	@echo "  │      → Accessibility   → enable Canopy              │"
	@echo "  │      → Input Monitoring → enable Canopy             │"
	@echo "  │   3. Press ⌥Space anywhere to open the overlay      │"
	@echo "  └─────────────────────────────────────────────────────┘"
	@echo ""

# ── Open ───────────────────────────────────────────────────────────────────────
open:
	@open "$(DEST)" 2>/dev/null || { echo "  ✗  Canopy is not installed. Run: make install"; exit 1; }

# ── Dev run (build + launch, no install) ───────────────────────────────────────
run: build
	@echo "  Launching $(APP) from build folder..."
	@open "$(PRODUCT)"

# ── Uninstall ──────────────────────────────────────────────────────────────────
uninstall:
	@if [ -d "$(DEST)" ]; then \
		killall $(APP) 2>/dev/null || true; \
		rm -rf "$(DEST)"; \
		echo "  ✓  Canopy removed from /Applications"; \
	else \
		echo "  Canopy is not installed."; \
	fi

# ── Clean ──────────────────────────────────────────────────────────────────────
clean:
	@rm -rf "$(BUILD_DIR)"
	@echo "  ✓  Build artefacts removed"
