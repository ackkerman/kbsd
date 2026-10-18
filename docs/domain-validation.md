# 独自ドメインの検証

- Pagesのkbsdプロジェクトにkbsd.0xdope.comを関連付ける。
- DNSに既存の競合レコードがないことを確認し、CNAMEをkbsd.pages.devへ向ける。
- 公開URLが有効な証明書でHTTPS 200を返す。
- HTMLのcanonical/og:url、packageのhomepage、README、GitHub homepage、Release本文のLPリンクを新ドメインへ合わせる。
- 公開LPの試聴・アプリダウンロード・GitHubリンクを確認する。
- 署名の並行作業・ネイティブアプリ・Releaseバイナリは更新しない。
