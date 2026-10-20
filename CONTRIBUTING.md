# Contributing

Annes Engine is maintained primarily as the shared foundation for Quartet Labo
LLC.'s semi-custom web application development services. We are not currently
accepting external pull requests or code contributions.

## Issues and Feedback

Issues may be opened to share reproducible defects, questions, or feature
requests. Issues are treated as information for maintainers and do not guarantee
a response, investigation, fix, feature, or delivery date. Contracted projects
and customers with active support agreements are prioritized.

Please do not submit a pull request unless a maintainer has explicitly requested
it. Unsolicited pull requests will be closed without review or merge.

## Security Reports

Do not include vulnerability details in a public issue. Follow the
[security policy](SECURITY.md) and use the private reporting channel described
there.

## Generated Test Logs

Keep generated files under `annes_*/test/dummy/log/` out of Git; only `.keep`
placeholders belong there. Preserve each dummy application's ignore rules when
moving or renaming it. Run `ruby test/dummy_log_hygiene_test.rb` before committing
test infrastructure changes. CI checks the tracked paths as well as the audit
and loyalty dummy apps' ignore rules, so force-added logs are detected too.
If a log may contain sensitive information, use the private security reporting
channel rather than posting its contents in an issue or pull request.

This policy may be revised before external code contributions are accepted. A
future contribution process may require a Developer Certificate of Origin or a
Contributor License Agreement.
