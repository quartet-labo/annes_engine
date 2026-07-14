# frozen_string_literal: true

require "minitest/autorun"
require "pathname"

class PublicProjectPolicyTest < Minitest::Test
  ROOT = Pathname(__dir__).join("..").expand_path
  POLICY_FILES = %w[MIT-LICENSE SUPPORT.md CONTRIBUTING.md SECURITY.md].freeze
  ENGINE_READMES = %w[anne_auth anne_access anne_admin].to_h do |engine|
    [ engine, ROOT.join(engine, "README.md") ]
  end.freeze

  def test_public_policy_files_exist
    POLICY_FILES.each do |relative_path|
      assert ROOT.join(relative_path).file?, "Missing public policy file: #{relative_path}"
    end
  end

  def test_readme_explains_project_scope_license_and_support
    readme = ROOT.join("README.md").read

    %w[Project\ Scope License Support Contributing Security].each do |heading|
      assert_match(/^## #{heading}$/i, readme)
    end

    assert_match(/semi-custom web application development/i, readme)
    assert_match(/contracted projects.*active support agreements.*priorit/i, readme)
    assert_match(/commercial and non-commercial use/i, readme)
    assert_match(/does not include support.*maintenance.*bug fixes.*feature development.*compatibility.*release commitments/im, readme)

    assert_includes readme, "[MIT License](MIT-LICENSE)"
    assert_includes readme, "[support policy](SUPPORT.md)"
    assert_includes readme, "[contribution policy](CONTRIBUTING.md)"
    assert_includes readme, "[security policy](SECURITY.md)"
  end

  def test_support_policy_separates_community_use_from_paid_services
    support = ROOT.join("SUPPORT.md").read

    assert_match(/^## Community Use$/i, support)
    assert_match(/^## Paid Services$/i, support)
    assert_match(/^### Standard Support$/i, support)
    assert_match(/best-effort/i, support)
    assert_match(/does not include an SLA/i, support)
    assert_match(/response time.*recovery time.*resolution deadline.*uptime/im, support)
    assert_match(/contracted projects.*active support agreements.*priorit/i, support)
    assert_match(/does not create.*support obligation/i, support)
  end

  def test_contribution_policy_declines_external_code_for_now
    contributing = ROOT.join("CONTRIBUTING.md").read

    assert_match(/not currently accepting external pull requests or code contributions/i, contributing)
    assert_match(/issues.*do not guarantee.*response.*investigation.*fix/im, contributing)
    assert_includes contributing, "[security policy](SECURITY.md)"
  end

  def test_security_policy_uses_private_vulnerability_reporting_without_a_timeline_guarantee
    security = ROOT.join("SECURITY.md").read

    assert_match(/^## Supported Versions$/i, security)
    assert_match(/^## Reporting a Vulnerability$/i, security)
    assert_match(/GitHub Private Vulnerability Reporting/i, security)
    assert_match(/do not open a public issue/i, security)
    assert_match(/do not guarantee.*response.*fix.*release/im, security)
  end

  def test_engine_readmes_link_to_the_repository_license_and_support_policy
    ENGINE_READMES.each do |engine, path|
      readme = path.read

      assert_includes readme, "https://github.com/quartet-labo/anne_engine/blob/main/MIT-LICENSE", engine
      assert_includes readme, "https://github.com/quartet-labo/anne_engine/blob/main/SUPPORT.md", engine
    end
  end
end
