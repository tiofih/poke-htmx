# frozen_string_literal: true

require "yaml"
require_relative "test_helper"

class CiStructureTest < Minitest::Test
  def compose
    YAML.safe_load_file(File.expand_path("../docker-compose.yml", __dir__))
  end

  def workflows
    Dir[File.expand_path("../.github/workflows/*.yml", __dir__)].map do |file|
      YAML.safe_load_file(file, aliases: true)
    end
  end

  def all_steps(workflow_list)
    workflow_list.flat_map do |wf|
      wf.fetch("jobs", {}).values.flat_map { |job| job.fetch("steps", []) }
    end
  end

  def workflow_triggers(workflow)
    # A chave `on` (gatilhos) é reservada em YAML 1.1 e o Psych pode interpretá-la
    # como boolean `true`; tolerar tanto a forma string quanto a boolean.
    workflow["on"] || workflow[true] || workflow["On"]
  end

  def test_db_has_healthcheck_pg_isready
    db = compose.fetch("services").fetch("db")
    healthcheck = db["healthcheck"]

    refute_nil healthcheck, "expected db service to define a healthcheck"
    test = healthcheck.fetch("test")
    joined = test.is_a?(Array) ? test.join(" ") : test.to_s
    assert_match(/pg_isready/, joined,
                 "expected db healthcheck to use pg_isready")
  end

  def test_workflow_has_expected_jobs
    refute_empty workflows, "expected at least one workflow in .github/workflows"

    job_names = workflows.flat_map { |wf| wf.fetch("jobs", {}).keys }
    %w[test lint check_docs].each do |job|
      assert_includes job_names, job,
                      "expected the CI workflow to define a #{job} job"
    end
  end

  def test_workflow_triggers_push_and_pull_request
    refute_empty workflows, "expected at least one workflow in .github/workflows"

    workflows.each do |wf|
      triggers = workflow_triggers(wf)
      refute_nil triggers, "expected the CI workflow to declare on triggers"
      assert_includes triggers.keys, "push", "expected a push trigger"
      assert_includes triggers.keys, "pull_request", "expected a pull_request trigger"
    end
  end

  def test_workflow_caches_build_and_bundle
    refute_empty workflows, "expected at least one workflow in .github/workflows"

    steps = all_steps(workflows)

    build_action = steps.find { |s| s.fetch("uses", "").include?("docker/build-push-action") }
    refute_nil build_action, "expected a docker/build-push-action step (build cache)"
    assert_equal "type=gha", build_action.dig("with", "cache-from"),
                 "expected build cache-from type=gha"
    assert_match(/type=gha/, build_action.dig("with", "cache-to").to_s,
                 "expected build cache-to type=gha")

    bundle_cache = steps.find { |s| s.fetch("uses", "").include?("actions/cache") }
    refute_nil bundle_cache, "expected an actions/cache step (bundle cache)"
    assert_equal "vendor/bundle", bundle_cache.dig("with", "path"),
                 "expected bundle cache path vendor/bundle"
    assert_match(/Gemfile\.lock/, bundle_cache.dig("with", "key").to_s,
                 "expected bundle cache key to hash Gemfile.lock")
  end
end
