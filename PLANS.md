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
- [x] 公開先と検証結果を記録する

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

## 公開結果
- ソース: https://github.com/ackkerman/kbsd
- Release: https://github.com/ackkerman/kbsd/releases/tag/v1.0.0
- LP: https://kbsd.pages.dev/
- Cloudflare配信: https://eb18bade.kbsd.pages.dev
- 公開ZIPを匿名のダウンロードURLから取得し、SHA256一致と展開後の署名・182音声レンダリングを検証した。
- 公開LPで試聴完了、元録音の表示、リンク、コンソールエラーなしを確認。GitHub homepage/READMEからLPへのリンクも確認した。
- ソースには私的履歴・資格情報・ビルドキャッシュ・旧サイトの画像/HTML/CSSを含めず、録音は許可確認済みのものだけを出典付きで同梱する。
- ライセンスは未指定のまま。ReleaseはApple Silicon / macOS14+、アドホック署名で未公証。
- 改名によりバンドルIDが変わるため、グローバル打鍵音を使う場合はkbsdに対してOS権限を改めて設定する。
- 修正後のGitHub Actions（4e5f913）はweb/nativeとも成功。ローカル検証に加えて、クリーンなCI環境でソースからのテスト・パッケージ化が成功した。
- agent-pattern-memoryに基づく振り返りを実施し、再利用ルールをAGENTS.mdへ反映した。私的な実行履歴は公開対象へ追加していない。

## サイド会話: 更新後もアクセシビリティ許可を維持する署名

### 目的
アドホック署名のcdhash変更で別アプリと判定される問題を避け、固定の署名証明書とバンドルIDを使用する。メインの公開処理や既存Releaseはこの作業から実行・更新しない。

### 進捗
- [x] 現在の証明書が0件、署名要件がcdhash固定であることを確認する。
- [x] 固定署名IDの選択、アドホックへの後戻り防止、別出力先での検証を実装する。
- [x] 一時ファイル以外に秘密鍵を出力しない証明書セットアップ手順を用意する。
- [x] 署名コマンドと失敗ケースをテストする。
- [x] キーチェーン変更への承認後、固定証明書を登録し、異なる2版の識別条件を検証する。
- [x] 旧署名からの一度限りの権限移行を確認する。

### 判断・制約
固定署名は通常の更新で同じアプリとして識別されるための対策。OSの権限リセット、利用者の取り消し、証明書やバンドルIDの変更後まで許可が永久に残るとは保証しない。秘密鍵はリポジトリに置かず、コード署名用途に限定したユーザーキーチェーンで保持する。証明書作成・鍵登録・信頼設定と、OS権限の移行は事前確認後に実施する。

### 検証
`bash -n native/scripts/sign-app.sh native/scripts/setup-local-signing.sh`、`python3 -m unittest discover -s native/Tests/SigningTests`。実署名は使い捨てのfixtureと独立した出力先で検証し、実行中のdist/kbsd.appを上書きしない。

## LPの独自ドメイン設定
- [x] Cloudflare Pagesと0xdope.comのDNS状態を確認する。
- [x] kbsd.0xdope.comをPagesへ接続し、必要なDNSを設定する。
- [x] LPのURLメタデータ、README、GitHub homepage、Release本文を新ドメインへ統一する。
- [x] 公開HTTPS・試聴・相互リンクを確認して結果を記録する。

署名の並行作業には触れず、Webとドメイン設定だけを対象にする。既存DNSの上書きが必要な場合は、対象を確認してから判断する。

### 固定署名の準備結果
- 固定IDの選択・破損設定・署名失敗・弱い識別条件・証明書署名からの後戻り防止の10テストが成功。
- `KBSD_APP_PATH`で独立した検証出力へパッケージし、182音声のレンダリングと署名検証が成功。起動中のdist/kbsd.appを上書きしていない。
- キーチェーンへの証明書・秘密鍵登録はユーザーの確認待ち。現時点では作成していない。

### 独自ドメインの結果
- kbsd.0xdope.comのプロキシ済みCNAMEをkbsd.pages.devへ追加。既存のroot/ui/wwwレコードは変更していない。
- Pagesのdomain/verification/validationはすべてactive。HTTPS 200と証明書検証、公開canonical/og:urlの一致、ブラウザーでの試聴・エラーなしを確認。
- README/package homepage/GitHub homepage/Release本文を更新。Web変更だけを38f4fb8でpushし、4f029504.kbsd.pages.devへ再デプロイした。
- Webフォーマット・型チェック・8テスト・ビルド・配信出力4テストが成功。署名の並行変更とReleaseバイナリは更新していない。

### 固定署名の実行結果とコミット依頼
- ユーザーの承認後、kbsd Local Code Signing証明書をユーザーキーチェーンに登録した。秘密鍵は非エクスポート、信頼はcodeSign用途に限定した。鍵利用のOS認証はユーザーが実施した。
- コードハッシュが異なる2版を実署名し、designated requirementが完全一致することを確認した。実アプリの固定署名・182音声診断も成功。
- 固定署名版をユーザー用Applicationsへ配置。起動元と証明書に固定された署名条件を確認し、UIのKeyboard access is enabledとユーザーの「なおった」という回答を確認した。
- ユーザーから、この変更のコミットと必要なRelease更新を依頼された。既存v1.0.0のSwiftアプリコードは変更せず、同じURLの配布ZIPを固定署名版に更新する。タグは付け替えない。


### 固定署名の検証と配布物更新
- 別出力の固定署名版に対するmake checkが成功。Web 8件、Swift 15件、署名・Release経路11件、182音源レンダリングが成功した。
- ユーザーが固定署名版の動作復旧を確認し、変更のコミットと必要なRelease更新を依頼した。
- Releaseの別出力を指定した際も、その署名済み.appをZIPに入れる回帰テストを追加した。
- 既存v1.0.0のURLとアプリバージョンは維持する。旧配布物をローカルに退避してから署名修正版ZIP・SHA256・説明を更新する。タグの付け替えやLPの再デプロイは行わない。

### 固定署名版の公開検証結果
- 変更を`d12e711`でコミットし、origin/mainへPushした。証明書・秘密鍵・ローカル署名設定は含めていない。
- 既存v1.0.0の旧ZIPとSHA256をローカルへ退避後、同じURLの配布物とReleaseノートを更新した。既存タグの付け替えは行っていない。
- GitHubからZIPとSHA256を再ダウンロードし、チェックサム成功、ローカル生成物とのバイト一致、署名検証成功、インストール版と同じDRであることを確認した。
- agent-pattern-memoryの実行後振り返りはローカルの非公開ログへ記録した。公開ソースには再発防止ルールと検証仕様を残した。
- GitHub ActionsのCheck（変更コミットd12e711）はweb/native両ジョブが成功した。
