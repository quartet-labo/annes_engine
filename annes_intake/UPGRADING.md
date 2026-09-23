# Upgrading AnnesIntake

## 0.1.0

初回導入です。FormKit 0.1.0を先に公開してからIntakeをPublish Gemsで公開してください。タグの手動pushは不要です。

Inquiryからの自動移行はありません。既存Inquiryホストの設定やmigrationは変わりません。Intakeを利用するときだけgem・mount・専用migration・flow adapter・定義認可を追加します。公開済みInquiry定義はホストが両側の認可を行い、明示的に新規draftへコピーできます。回答・adapter・ID・同期関係はコピーしません。

旧未マージPRの実験的なInquiryフローDBは移行対象外です。正式なInquiry 0.1.0/0.2.0からは追加機能の独立導入となります。

管理画面でのフォーム・フロー作成では本体と初版も認可対象です。definition_authorizerは新規レコードを正しい所有scopeへ含めてください。子定義が閲覧範囲外のプレビューやフロー詳細は表示を拒否します。DB変更はありません。
