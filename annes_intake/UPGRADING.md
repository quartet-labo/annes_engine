# Upgrading AnnesIntake

## 0.1.0

初回導入です。FormKit 0.1.0を先に公開してからIntakeをPublish Gemsで公開してください。タグの手動pushは不要です。

Inquiryからの自動移行はありません。既存Inquiryホストの設定やmigrationは変わりません。Intakeを利用するときだけgem・mount・専用migration・flow adapter・定義認可を追加します。公開済みInquiry定義はホストが両側の認可を行い、明示的に新規draftへコピーできます。回答・adapter・ID・同期関係はコピーしません。

旧未マージPRの実験的なInquiryフローDBは移行対象外です。正式なInquiry 0.1.0/0.2.0からは追加機能の独立導入となります。

## 未公開Plan5候補から追加質問対応候補への更新

両方とも未公開の0.1.0候補です。新たな公開済みバージョンとして扱いません。Plan5のmigrationは変更せず、`CreateAnnesIntakeFollowUps`と`HardenAnnesIntakeFollowUpConstraints`を追加します。

回答者向け受付詳細では空の追加質問履歴を表示しません。この表示調整にホスト側の変更は不要です。

`bin/rails railties:install:migrations FROM=annes_intake`、`bin/rails db:migrate`を実行してください。既存run・Response・回答・添付の書換えや移行は不要です。`script/check_intake_package`は固定したPlan5 commitの配布gemで代表データを作成し、追加migration適用前後の全属性と添付バイト列を比較します。

追加質問を利用するホストは初回adapterへ`persist_follow_up!`と`admin_follow_up/admin_cancel_follow_up`認可を追加し、`scope_runs`に許可したresponse runを含めてください。回答時はrootとresponse両方の権限を確認します。発行通知と回答通知は`follow_up_request`を伴います。通知の再送判断・宛先・ログイン導線はホスト側で扱います。

専用定義は通常テンプレートと分離され、発行後は編集できません。サービスからの専用編集はREADMEの`DefinitionPolicy::Context`を利用します。未公開のIntake側`Definitions::ExportSchema`はcontext必須とし、専用定義の書き出しを拒否します。Inquiryの公開API・設定・migrationには変更ありません。
