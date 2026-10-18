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

## アクセシビリティ
フォーカス表示、ボタンの状態、スクリーンリーダー向けラベル、ライブ領域、reduce motionを提供する。権限がない場合はPreview onlyと表示する。
