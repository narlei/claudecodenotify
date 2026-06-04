# ClaudeCodeNotify — front-end de build/instalação.
# Backend padrão: SwiftPM. Fallback: Tuist (ver alvo `tuist-setup`).

APP_NAME := ClaudeCodeNotify
APP := $(APP_NAME).app
DIST := dist
CONFIG ?= release
VERSION := $(shell /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Resources/Info.plist 2>/dev/null)

.DEFAULT_GOAL := build

.PHONY: setup build run app zip dmg release install uninstall clean help

help: ## Lista os alvos disponíveis
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

setup: ## Valida toolchain e instala deps (create-dmg) se faltarem
	@echo "==> verificando toolchain"
	@swift --version
	@xcodebuild -version 2>/dev/null | head -1 || true
	@python3 -c "import dmgbuild" >/dev/null 2>&1 || { \
		echo "==> instalando dmgbuild (para 'make dmg')"; \
		python3 -m pip install --user --quiet dmgbuild || echo "   (falhou — pule se não for gerar .dmg)"; }
	@echo "==> ok"

build: ## Compila (swift build -c $(CONFIG))
	swift build -c $(CONFIG)

run: ## Compila e roda em modo dev (sem bundle)
	swift run -c debug $(APP_NAME)

app: ## Monta o $(APP) (Info.plist + ad-hoc sign)
	./Scripts/build-app.sh $(CONFIG)

zip: app ## Empacota o $(APP) em $(DIST)/$(APP_NAME)-$(VERSION).zip (GitHub Releases)
	@mkdir -p $(DIST)
	@rm -f $(DIST)/$(APP_NAME)-*.zip
	@ditto -c -k --keepParent $(APP) "$(DIST)/$(APP_NAME)-$(VERSION).zip"
	@codesign --verify --verbose "$(APP)" 2>&1 | tail -1
	@echo "==> $(DIST)/$(APP_NAME)-$(VERSION).zip"

dmg: app ## Cria o $(DIST)/$(APP_NAME).dmg (arraste pro Applications)
	./Scripts/make-dmg.sh

release: zip dmg ## Gera todos os artefatos de release (zip e dmg)

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
