# kbsd for Windows

Windows 10/11 x64版。通知領域に常駐し、7音色の押下・解放音、音量、ピッチ、ランダムピッチ、左右の広がり、修飾キー・マウス音、日次・累計統計を設定できます。設定UIはSwift版と同じサイドバー・音色カード・ティールのアクセントに揃えています。

## 起動

配布ZIPをフォルダーごと展開し、`kbsd.exe`を起動します。`Sounds/`とランタイムファイルを同じフォルダーに保持してください。.NETの別途インストールや管理者権限は不要です。Windows版はAuthenticode署名されていません。

設定画面を閉じると通知領域で動作を続けます。アイコンをダブルクリックすると設定を開き、右クリックすると有効／無効、音色、終了を選択できます。隠れている場合は通知領域の展開ボタンを確認してください。

WindowsではmacOSのアクセシビリティ許可設定は不要です。Raw Inputで物理入力のコード・上下・種別だけを受信し、入力を変更・遮断しません。文字列、キー履歴、アプリ名を保存・送信しません。管理者アプリ、リモート接続、仮想キーボード、セキュアデスクトップなどの入力経路での動作は環境に依存します。合成入力は実キーボードの監視確認として扱いません。

`General → Launch at login`はユーザーの操作でのみ現在の実行ファイルを登録します。有効にする前に展開先を固定してください。Windowsのスタートアップ設定で別途無効化されている場合は、その状態も確認してください。移動・削除前に登録を解除してください。

設定と集計値はユーザーのLocalAppData内の`kbsd/state.json`に保存されます。画面ロック、セッション切断、スリープ時は発音を停止します。入力登録や音声出力に失敗した場合は画面に表示し、`Retry audio and input`で再試行できます。入力登録に失敗しても試聴は利用できます。

## ビルドと検証

Windows、.NET 10 SDK、PowerShell 7が必要です。Windows Formsの常駐基盤とWPFのベクターUIを使用します。リポジトリルートで実行します。

```powershell
dotnet run --project windows/Kbsd.Desktop -c Release
pwsh -NoProfile -File windows/scripts/check.ps1
pwsh -NoProfile -File windows/scripts/package.ps1
```

`make check`はWindowsではWeb検証とWindows検証、macOSではWeb検証と既存Swift検証を実施します。`make windows-package`はランタイム・元録音182個・出典を同梱した`dist/windows/kbsd-v1.0.0-windows-x64.zip`と`SHA256SUMS.txt`を生成します。自動公開はしません。Windows CIも同じ検証とZIP作成を行い、成果物として保存します。

```powershell
Get-FileHash -Algorithm SHA256 dist/windows/kbsd-v1.0.0-windows-x64.zip
```

診断はデコードだけでなく、全サンプルを本番と同じミキサーへscheduleし、全長の有限・非ゼロPCMを検証します。`--output`を付けると実際のWindows出力デバイスへ短い試聴音も送ります。

```powershell
$p = Start-Process -FilePath ./dist/windows/kbsd/kbsd.exe -ArgumentList '--diagnose --output --report diagnostic.json' -Wait -PassThru -WindowStyle Hidden
Get-Content -Encoding UTF8 diagnostic.json
if ($p.ExitCode -ne 0) { throw 'Diagnostic failed' }
```

元録音の権利・配布許可は同梱の`ATTRIBUTION.md`を参照してください。ソース・素材のライセンスは未指定です。
