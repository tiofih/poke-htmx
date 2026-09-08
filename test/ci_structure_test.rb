# frozen_string_literal: true

require "yaml"
require_relative "test_helper"

class CiStructureTest < Minitest::Test
  def compose
    YAML.safe_load_file(File.expand_path("../docker-compose.yml", __dir__))
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
end
