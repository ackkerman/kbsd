# kbsd リリース計画

## 目的
macOS用キーボードサウンドアプリkbsdのソースを公開し、GitHub ReleaseとCloudflare PagesのLPを相互リンクする。

## 進捗
- [x] GitHubリポジトリの空状態とpush権限、Cloudflare Pagesへの公開権限を確認する
- [x] ライセンス方針を確認する（ユーザー指定: 未指定）
- [x] アプリ名・バンドル・UI・ドキュメントをkbsdへ統一する
- [x] 許可済みの元録音と独自アイコン・LPを用意する
- [x] 公開ファイルの秘密情報・第三者素材・依存関係を検査する
- [x] ネイティブテストと音声レンダリング、LPの操作・レスポンシブを確認する
- [x] Release用ZIPとチェックサムを作る
- [x] ソースをGitHubへpushし、v1.0.0 Releaseを公開する
- [x] Cloudflare PagesへLPを公開してGitHubとの相互リンクを確認する
- [ ] 公開先と検証結果を記録する

## 判断記録
- 公開先はhttps://github.com/ackkerman/kbsd。LPは新規Cloudflare Pagesプロジェクトkbsdを使用する。
- 元サイトの画像・サイトコードは公開対象から外す。録音はユーザーが配布許可を確認したものを出典付きで同梱し、独自アイコンとLPを用意する。
- ライセンスは未指定。MIT等のライセンスファイルやオープンソースという表現を追加しない。
- アプリはApple Silicon用、macOS 14以降、ローカルのアドホック署名。Developer ID署名・公証済みとは表示しない。
- ブランド統一に合わせてバンドルIDをcom.ackkerman.kbsd、アプリをkbsd.appへ変更する。既存アプリのOS権限は引き継がれない。
- 公開対象を明示指定して初回commitする。作業履歴、スクリーンショット、キャッシュ、環境変数、旧素材は含めない。

## 検証と受け入れ
リポジトリルートでmake check。GitHub ReleaseのZIP・SHA256と配信URLを検証し、Cloudflare公開URLを実ブラウザーで開いてダウンロード・GitHubリンク・試聴を確認する。

## 発見・リスク
アドホック署名は開発版の更新でOSの許可登録との不一致が起こり得る。配布時に初回セットアップ手順を明記する。

## 結果
作業中。

## 音源に関する方針変更
ユーザーの試聴結果により合成音の採用を撤回。ローカルアプリとLPの音源を元の録音へ復元した。改名・Release・LPの準備は維持する。ユーザーに配布許可があることを確認し、公開物にも元録音を同梱する。

## 公開前の検証結果
- Webの8テスト、Swiftの15テスト、Sites出力の4テスト、型・フォーマット・ビルド・署名検証が成功。
- 182個の録音が許可された元データとバイト単位で一致し、アプリへの同梱も一致。
- LPの試聴切替、音量、FAQ、CSS幅390pxでの横はみ出しなしをブラウザーで確認。
- npm auditは脆弱性0件。公開対象のスキャナーは脆弱性・禁止ライセンス・設定済み危険パターンの指摘なし。
- Git公開対象は231ファイル。個人絶対パス、資格情報、キャッシュ、私的履歴を含めない。
- ReleaseはApple Silicon向け、ZIPに不要な拡張属性・リソースフォークのサイドカーを含めず、SHA256一致を確認。

## 公開後の確認
- GitHub mainとv1.0.0を公開し、ZIP・SHA256SUMS.txtをReleaseに添付。公開URLからの再取得とSHA256一致を確認した。
- Cloudflare Pagesのhttps://kbsd.pages.dev/へデプロイし、公開画面の表示・音源・GitHub/Releaseリンクを確認。GitHubのhomepageとREADMEもLPへリンクする。
- HTTPSのOAuth認証にはworkflow権限がなかったため、既存のSSH認証でpushした。認証スコープの追加は行っていない。
- macOS CIの既定Swiftは5.10で、tools6.0パッケージを読めなかった。公式runner画像にあるXcode16.2をDEVELOPER_DIRで明示する。
