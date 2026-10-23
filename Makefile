.PHONY: help install dev lint typecheck test build format docs check validate
help: ## コマンド一覧
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "%-16s %s\n", $$1, $$2}' $(MAKEFILE_LIST)
install: ## 依存を導入
	npm install
dev: ## ローカル起動
	npm run dev -- --host 0.0.0.0 --port 4173
lint: ## フォーマット確認
	npm run format:check
typecheck: ## 型確認
	npm run typecheck
test: ## 操作契約と素材整合性
	npm test
build: ## 本番ビルド
	npm run build
format: ## フォーマット
	npm run format
docs: ## ドキュメント基盤確認
	node -e "for (const p of ['AGENTS.md','SPEC.md','DESIGN.md','PLANS.md','docs/test-list.md']) if (!require('node:fs').statSync(p).size) throw new Error(p)"
check: lint typecheck test build docs ## 標準検証
validate: check ## 標準検証の別名

.PHONY: native-test native-build native-package native-check native-run
native-test: ## ネイティブの仕様テスト
	swift test --package-path native
native-build: ## ネイティブreleaseビルド
	swift build --package-path native -c release
native-package: ## Finder起動可能な.appを作成し診断
	bash native/scripts/package-app.sh
native-check: native-test native-package ## ネイティブの標準検証
	bash -n native/scripts/package-app.sh
native-run: native-package ## ネイティブアプリを起動
	open dist/kbsd.app

.PHONY: native-format-check
native-format-check: ## Swiftフォーマット確認
	xcrun swift-format lint --strict --recursive native/Sources native/Tests native/Package.swift
native-check: native-format-check
ifeq ($(OS),Windows_NT)
check: windows-check
else
check: native-check
endif

.PHONY: release
release: ## 配布ZIPとSHA256を生成
	bash scripts/package-release.sh

.PHONY: native-signing-test
native-signing-test: ## 固定署名の選択と後戻り防止を検証
	python3 -m unittest discover -s native/Tests/SigningTests
native-check: native-signing-test

DOTNET ?= dotnet
.PHONY: windows-check windows-package windows-installer windows-run
windows-check: ## Windowsのフォーマット・ビルド・テスト・182音源診断
	pwsh -NoProfile -File windows/scripts/check.ps1 -Dotnet "$(DOTNET)"
windows-package: ## Windows x64用ZIPとSHA256を生成
	pwsh -NoProfile -File windows/scripts/package.ps1 -Dotnet "$(DOTNET)"
windows-installer: windows-package ## WindowsのインストーラーとSHA256を生成（Inno Setupが必要）
	pwsh -NoProfile -File windows/scripts/installer.ps1
windows-run: ## Windowsの設定画面と通知領域アプリを起動
	$(DOTNET) run --project windows/Kbsd.Desktop -c Release
