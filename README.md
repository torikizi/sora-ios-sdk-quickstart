# Sora iOS SDK クイックスタート

このアプリケーションは [Sora iOS SDK](https://github.com/shiguredo/sora-ios-sdk) のサンプルです。

## About Shiguredo's open source software

We will not respond to PRs or issues that have not been discussed on Discord. Also, Discord is only available in Japanese.

Please read https://github.com/shiguredo/oss before use.

## 時雨堂のオープンソースソフトウェアについて

利用前に https://github.com/shiguredo/oss をお読みください。

## システム条件

- iOS 10.0 以降
- アーキテクチャ arm64, x86_64 (シミュレーターの動作は未保証)
- macOS 10.15 以降
- Xcode 11.1
- Swift 5.1
- CocoaPods 1.6.1 以降
- WebRTC SFU Sora 2020.3 以降

Xcode と Swift のバージョンによっては、 Carthage と CocoaPods で取得できるバイナリに互換性がない可能性があります。詳しくは[ Sora iOS SDK ドキュメント](https://sora-ios-sdk.shiguredo.jp/) を参照してください。

## ビルド

1. クローンし、 CocoaPods でライブラリを取得します。

   ```
   $ git clone https://github.com/shiguredo/sora-ios-sdk-quickstart
   $ cd sora-ios-sdk-quickstart
   $ pod install
   ```

2. ``SoraQuickStart.xcworkspace`` を Xcode で開いてビルドします。
