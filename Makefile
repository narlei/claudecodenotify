# ClaudeCodeNotify — build/installation front-end.
# Default backend: SwiftPM. Fallback: Tuist (see target `tuist-setup`).

APP_NAME := ClaudeCodeNotify
APP := $(APP_NAME).app
DIST := dist
CONFIG ?= release
VERSION := $(shell /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Resources/Info.plist 2>/dev/null)

.DEFAULT_GOAL := build

.PHONY: setup build run app dev zip dmg release install uninstall clean help \
        bump_patch bump_minor bump_major

help: ## Lists available targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

setup: ## Validates toolchain and installs missing deps (create-dmg)
	@echo "==> checking toolchain"
	@swift --version
	@xcodebuild -version 2>/dev/null | head -1 || true
	@python3 -c "import dmgbuild" >/dev/null 2>&1 || { \
		echo "==> installing dmgbuild (for 'make dmg')"; \
		python3 -m pip install --user --quiet dmgbuild || echo "   (failed — skip if not building .dmg)"; }
	@echo "==> ok"

build: ## Builds (swift build -c $(CONFIG))
	swift build -c $(CONFIG)

run: ## Builds and runs in dev mode (no bundle)
	swift run -c debug $(APP_NAME)

app: ## Assembles $(APP) (Info.plist + ad-hoc sign)
	./Scripts/build-app.sh $(CONFIG)

zip: app ## Packages $(APP) to $(DIST)/$(APP_NAME)-$(VERSION).zip (GitHub Releases)
	@mkdir -p $(DIST)
	@rm -f $(DIST)/$(APP_NAME)-*.zip
	@ditto -c -k --keepParent $(APP) "$(DIST)/$(APP_NAME)-$(VERSION).zip"
	@codesign --verify --verbose "$(APP)" 2>&1 | tail -1
	@echo "==> $(DIST)/$(APP_NAME)-$(VERSION).zip"

dmg: app ## Creates $(DIST)/$(APP_NAME).dmg (drag to Applications)
	./Scripts/make-dmg.sh

release: zip dmg ## Builds all release artifacts (zip and dmg)

dev: app ## Clears all app state (first-launch) and opens a fresh build
	@echo "==> killing running instance (if any)"
	@pkill -x ClaudeCodeNotify 2>/dev/null || true
	@sleep 0.3
	@echo "==> clearing app state"
	@rm -f "$$HOME/Library/Application Support/ClaudeCodeNotify/config.json"
	@rm -f "$$HOME/Library/Application Support/ClaudeCodeNotify/preferences.json"
	@defaults delete com.narlei.ClaudeCodeNotify 2>/dev/null || true
	@echo "==> launching"
	@open $(APP)

install: app ## Assembles and opens app (use menu to "Connect Claude Code")
	open $(APP)

uninstall: ## Runs app with --uninstall (removes hook from settings.json, with backup)
	@if [ -x "$(APP)/Contents/MacOS/$(APP_NAME)" ]; then \
		"$(APP)/Contents/MacOS/$(APP_NAME)" --uninstall; \
	else \
		swift run -c debug $(APP_NAME) --uninstall; \
	fi

clean: ## Removes .build/, $(APP) and $(DIST)/
	rm -rf .build $(APP) $(DIST)

# Bumps the semantic version in Resources/Info.plist.
# $(1) = patch | minor | major — resets lower components and bumps the build number.
define bump_version
	@cur=$$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Resources/Info.plist); \
	new=$$(echo "$$cur" | awk -F. -v part="$(1)" '{if(part=="major"){$$1++;$$2=0;$$3=0}else if(part=="minor"){$$2++;$$3=0}else{$$3++}printf "%d.%d.%d",$$1,$$2,$$3}'); \
	build=$$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" Resources/Info.plist); \
	newbuild=$$((build + 1)); \
	/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $$new" Resources/Info.plist; \
	/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $$newbuild" Resources/Info.plist; \
	echo "==> version $$cur -> $$new   (build $$build -> $$newbuild)"; \
	echo "    commit & push to main to release: git commit -am \"Release v$$new\" && git push"
endef

bump_patch: ## Bumps patch version x.y.(Z+1) in Info.plist
	$(call bump_version,patch)

bump_minor: ## Bumps minor version x.(Y+1).0 in Info.plist
	$(call bump_version,minor)

bump_major: ## Bumps major version (X+1).0.0 in Info.plist
	$(call bump_version,major)
