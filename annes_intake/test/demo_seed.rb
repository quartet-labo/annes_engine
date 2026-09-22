require_relative "dummy/config/environment"
abort "Demo setup requires INTAKE_DEMO=true and the browser test DB" unless ENV["INTAKE_DEMO"] == "true" && ActiveRecord::Base.connection_db_config.database == "annes_intake_browser_test"
flow = AnnesIntake::Flow.find_by(key: "consultation")
unless flow
  form = AnnesIntake::Form.create!(name: "ご相談内容")
  version = form.versions.create!(number: 1, title: form.name)
  version.fields.create!(key: "name", label: "お名前", required: true)
  choices = version.fields.create!(key: "services", label: "相談したいサービス", value_type: "multiple_choice", widget: "checkbox_group", position: 1)
  choices.options.create!(value: "website", label: "Webサイト制作", position: 0)
  choices.options.create!(value: "system", label: "業務システム", position: 1)
  version.fields.create!(key: "budget", label: "予算（万円）", value_type: "integer", widget: "number", position: 2)
  AnnesIntake::Definitions::PublishVersion.call(version, expected_lock_version: 0, context: :demo_admin)
  flow = AnnesIntake::Flow.create!(key: "consultation", name: "ご相談受付")
  fv = flow.versions.create!(number: 1, title: flow.name)
  first = fv.steps.create!(title: "ご相談内容", key: "contact", position: 0, form_version: version)
  %w[website system].zip(["Webサイト制作", "業務システム"]).each_with_index do |(key, title), index|
    template = AnnesIntake::Form.create!(name: title)
    v = template.versions.create!(number: 1, title: title)
    name = v.fields.create!(key: "name", label: "お名前", required: true)
    v.fields.create!(key: "details", label: "詳しいご要望", widget: "textarea", required: true, position: 1)
    AnnesIntake::Definitions::PublishVersion.call(v, expected_lock_version: 0, context: :demo_admin)
    step = fv.steps.create!(title: title, key: key, position: index + 1, form_version: v)
    step.condition_groups.create!.conditions.create!(source_step: first, field: choices, operator: "contains", expected_value: key)
    step.value_mappings.create!(source_step: first, source_field: version.fields.find_by!(key: "name"), target_field: name)
  end
  AnnesIntake::Flows::Definitions::PublishVersion.call(fv, expected_lock_version: 0, context: :demo_admin)
end
puts "/intake/flows/#{flow.key}"
