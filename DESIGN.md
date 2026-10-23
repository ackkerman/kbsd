---
version: "alpha"
name: "kbsd"
description: "A calm, tactile identity for native keyboard sounds."
colors:
  primary: "#252a28"
  background: "#faf7ef"
  surface: "#f2f1e8"
  text: "#252a28"
  accent: "#b2dfbb"
typography:
  body:
    fontFamily: "ui-sans-serif, system-ui, sans-serif"
    fontSize: "1rem"
    lineHeight: "1.6"
spacing:
  sm: "8px"
  md: "16px"
  lg: "32px"
rounded:
  sm: "8px"
  md: "16px"
components: {}
---

## 視覚原則
クリーム色の背景、濃い緑の文字、ミント色のキートップの独自アイコンを使用する。大きなタイポグラフィと余白で、音とネイティブアプリの体験を説明する。

## コンポーネント
LPはブランドヘッダー、ダウンロード、7音色の操作パネル、実アプリのスクリーンショット、機能紹介、セットアップ、FAQ、GitHubへの導線を持つ。モバイルは一列にする。

## ネイティブ
SwiftUIのメニューバーと独立した設定ウィンドウ。システムフォントとマテリアル、ティールのアクセントを使用する。音色の色はSlate/Violet/Pebble/Paper/Honey/Ruby/Creamに対応する。

Windows版はWindows Formsの通知領域・ウィンドウ基盤にWPFのベクターUIを組み合わせ、Swift版の体裁に揃える。184pxの淡いグレーのサイドバー、ティールの選択表示、同じアプリアイコン、2列の音色カード、色付きキートップ、独立した試聴ボタン、右上の有効スイッチを使用する。Switches / Sound / General / Statisticsの構成と文言を揃え、入力試用欄は文字を表示・保持しないフォーカス可能なボタンとする。キーボードフォーカス、DPIスケーリング、スクリーンリーダー用のラベルを提供する。入力登録や音声出力の失敗と再試行を設定画面で表示する。

## アクセシビリティ
フォーカス表示、ボタンの状態、スクリーンリーダー向けラベル、ライブ領域、reduce motionを提供する。権限がない場合はPreview onlyと表示する。
