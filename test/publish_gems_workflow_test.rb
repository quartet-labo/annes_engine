# frozen_string_literal: true

require "minitest/autorun"
require "pathname"
require "yaml"

class PublishGemsWorkflowTest < Minitest::Test
  ROOT = Pathname(__dir__).join("..").expand_path
  WORKFLOW_PATH = ROOT.join(".github/workflows/publish-gems.yml")

  def test_workflow_is_dispatch_only
    triggers = workflow.fetch("on") { workflow.fetch(true) }

    assert_equal [ "workflow_dispatch" ], triggers.keys
    refute_includes workflow_source, "push:"
    refute_includes workflow_source, "tags:"
  end

  def test_dispatch_inputs_require_one_gem_and_version
    inputs = workflow.fetch("on") { workflow.fetch(true) }.fetch("workflow_dispatch").fetch("inputs")
    gem_input = inputs.fetch("gem")
    version_input = inputs.fetch("version")

    assert_equal true, gem_input.fetch("required")
    assert_equal "choice", gem_input.fetch("type")
    assert_equal %w[annes_auth annes_admin annes_access annes_audit annes_loyalty], gem_input.fetch("options")
    refute_includes gem_input.fetch("options"), "all"

    assert_equal true, version_input.fetch("required")
    assert_equal "string", version_input.fetch("type")
  end

  def test_publish_job_uses_release_preparation_script_without_a_matrix
    publish_job = workflow.fetch("jobs").fetch("publish")

    refute_includes publish_job.keys, "strategy"
    assert_includes workflow_source, "ruby script/prepare_gem_release"
  end

  def test_dispatch_inputs_are_passed_through_quoted_environment_variables
    prepare_step = workflow_step("Prepare release")
    env = prepare_step.fetch("env")
    run = prepare_step.fetch("run")

    assert_equal "${{ github.event.inputs.gem }}", env.fetch("RELEASE_GEM")
    assert_equal "${{ github.event.inputs.version }}", env.fetch("RELEASE_VERSION")
    assert_includes run, 'notes_file="${RUNNER_TEMP}/${RELEASE_GEM}-${RELEASE_VERSION}-release-notes.md"'
    assert_includes run, '--gem "$RELEASE_GEM"'
    assert_includes run, '--version "$RELEASE_VERSION"'
    refute_includes run, "github.event.inputs.gem"
    refute_includes run, "github.event.inputs.version"
  end

  def test_publish_job_rejects_non_main_refs_before_checkout
    assert_includes workflow_source, 'if [[ "$GITHUB_REF" != "refs/heads/main" ]]'
    assert_operator workflow_source.index("- name: Verify dispatch ref"), :<, workflow_source.index("- name: Checkout")
  end

  def test_checkout_uses_node_24_compatible_action
    assert_equal "actions/checkout@v7", workflow_step("Checkout").fetch("uses")
  end

  def test_publish_job_checks_remote_tag_before_publishing
    assert_includes workflow_source, "git ls-remote --tags origin \"$tag_name\""
    assert_operator(
      workflow_source.index("git ls-remote --tags origin \"$tag_name\""),
      :<,
      workflow_source.index("gem push --key github")
    )
  end

  def test_publish_success_creates_tag_and_github_release
    assert_operator workflow_source.index("gem push --key github"), :<, workflow_source.index("git tag \"$tag_name\" \"$GITHUB_SHA\"")
    assert_operator workflow_source.index("git tag \"$tag_name\" \"$GITHUB_SHA\""), :<, workflow_source.index("git push origin \"$tag_name\"")
    assert_operator workflow_source.index("git push origin \"$tag_name\""), :<, workflow_source.index("gh release create \"$tag_name\"")
  end

  private
    def workflow
      @workflow ||= YAML.load_file(WORKFLOW_PATH)
    end

    def workflow_source
      @workflow_source ||= WORKFLOW_PATH.read
    end

    def workflow_step(name)
      workflow.fetch("jobs").fetch("publish").fetch("steps").find do |step|
        step.fetch("name") == name
      end || flunk("Missing workflow step: #{name}")
    end
end
