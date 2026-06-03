# ClaudeCodeNotify — front-end de build/instalação.
# Backend padrão: SwiftPM. Fallback: Tuist (ver alvo `tuist-setup`).

APP_NAME := ClaudeCodeNotify
APP := $(APP_NAME).app
DIST := dist
CONFIG ?= release

.DEFAULT_GOAL := build

.PHONY: setup build run app zip install uninstall clean help

help: ## Lista os alvos disponíveis
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

setup: ## Valida toolchain (Swift/Xcode)
	@echo "==> verificando toolchain"
	@swift --version
	@xcodebuild -version 2>/dev/null | head -1 || true
	@echo "==> ok"

build: ## Compila (swift build -c $(CONFIG))
	swift build -c $(CONFIG)

run: ## Compila e roda em modo dev (sem bundle)
	swift run -c debug $(APP_NAME)

app: ## Monta o $(APP) (Info.plist + ad-hoc sign)
	./Scripts/build-app.sh $(CONFIG)

zip: app ## Empacota o $(APP) em $(DIST)/$(APP_NAME).zip
	@mkdir -p $(DIST)
	@rm -f $(DIST)/$(APP_NAME).zip
	@cd . && ditto -c -k --keepParent $(APP) $(DIST)/$(APP_NAME).zip
	@echo "==> $(DIST)/$(APP_NAME).zip"

install: app ## Monta e abre o app (use o menu para "Conectar Claude Code")
	open $(APP)

uninstall: ## Roda o app com --uninstall (remove hook do settings.json, com backup)
	@if [ -x "$(APP)/Contents/MacOS/$(APP_NAME)" ]; then \
		"$(APP)/Contents/MacOS/$(APP_NAME)" --uninstall; \
	else \
		swift run -c debug $(APP_NAME) --uninstall; \
	fi

clean: ## Remove .build/, $(APP) e $(DIST)/
	rm -rf .build $(APP) $(DIST)
