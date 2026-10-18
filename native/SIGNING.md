# 更新時にプライバシー許可を維持する署名

macOSはアプリのバンドルIDだけでなくdesignated requirementで更新前後の同一性を確認する。アドホック署名のcdhash固定条件はビルドで変化するため、アクセシビリティの再許可が必要になる場合がある。

## 継続する署名ID

Apple Development / Developer ID証明書がある場合は、その署名IDを指定する。

```sh
KBSD_SIGN_IDENTITY="<signing identity>" make native-package
```

このMac用の固定証明書を使う場合は、内容を確認してから以下を一度だけ実行する。

```sh
bash native/scripts/setup-local-signing.sh
bash native/scripts/setup-local-signing.sh --create
```

セットアップはユーザーの既定キーチェーンへ証明書と非エクスポート鍵を登録する。信頼はcodeSign用途、秘密鍵への事前許可は/usr/bin/codesignだけに限定する。一時の秘密鍵ファイルは所有者専用ディレクトリに作り、終了時に削除する。固定IDはGit対象外の`.local/signing/identity`へ保存され、以後のビルドに再利用される。秘密鍵をリポジトリやReleaseへ含めない。

固定証明書が設定された後は、署名エラー時にアドホックへ切り替えない。既存の証明書署名済みアプリを署名ID未設定で上書きすることも拒否する。

## 既存アプリを上書きしない検証

```sh
KBSD_APP_PATH="$PWD/dist/signing-validation/kbsd.app" make native-package
```

`KBSD_APP_PATH`を省略すると従来どおり`dist/kbsd.app`を生成する。

## 移行と制約

旧アドホック署名から固定証明書へ移るときは、一度だけOS側の権限登録を差し替える必要がある。以後は同じ証明書・同じバンドルIDを使い続ける。証明書を作り直したり、バンドルIDを変えたり、利用者が権限を取り消したり、OSのプライバシー設定をリセットした場合まで維持されるとは保証しない。

このローカル証明書はDeveloper IDや公証の代わりではなく、配布先でのGatekeeper承認も保証しない。Developer IDで一般配布する場合は正式な署名・公証を別途行う。

参考: https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements
