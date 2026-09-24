# frozen_string_literal: true

require_relative "test_helper"
require "open3"
require "tempfile"
require "fileutils"

# Ferramentas da sessao 0097: so o que roda no container de teste
# (bash/awk/grep; git/docker/gh fora — medido). Fixture = saida real do
# minitest capturada com o demo temporario `test/zz_demo_fail_test.rb`
# (Passo 1, apagado na hora), em texto inline.
class ScriptsToolingTest < Minitest::Test
  MINITEST_FAIL_OUTPUT = <<~OUT
    Container poke-htmx-db-1  Running
    test> Container 'web' ativo — rake test nele.
    Run options: --seed 5407

    # Running:

    F

    Finished in 0.002035s, 491.5010 runs/s, 491.5010 assertions/s.

      1) Failure:
    ZzDemoFailTest#test_falha_proposital [test/zz_demo_fail_test.rb:9]:
    demo intencional.
    Expected: 1
      Actual: 2

    1 runs, 1 assertions, 1 failures, 0 errors, 0 skips
    rake aborted!
    Command failed with status (1)
  OUT

  TWO_FILES_FAIL_OUTPUT = <<~OUT
    Run options: --seed 1234

    # Running:

    FF

    Finished in 0.5s, 100.0 runs/s, 200.0 assertions/s.

      1) Failure:
    BattleRoutesTest#test_empate_por_hp [test/battle_routes_test.rb:42]:
    Expected: 1
      Actual: 2

      2) Error:
    TeamRoutesTest#test_remocao_id_inexistente [test/team_routes_test.rb:77]:
    NoMethodError: undefined method `x'

    2 runs, 2 assertions, 1 failures, 1 errors, 0 skips
    rake aborted!
  OUT

  def test_fails_report_gera_seed_falha_e_comando_de_repro
    with_raw_output(MINITEST_FAIL_OUTPUT) do |path|
      out, err, status = run_script("fails-report", path)
      assert status.success?, "exit #{status.exitstatus}: #{err}"
      assert_includes out, "seed 5407"
      assert_includes out, "  1) Failure:"
      assert_includes out, "ZzDemoFailTest#test_falha_proposital [test/zz_demo_fail_test.rb:9]:"
      assert_includes out, 'repro: TESTOPTS="--seed=5407" ./scripts/test test/zz_demo_fail_test.rb'
      assert_includes out, "-n /ZzDemoFailTest#test_falha_proposital/"
    end
  end

  def test_fails_report_files_extrai_lista_de_arquivos
    with_raw_output(TWO_FILES_FAIL_OUTPUT) do |raw|
      report = File.expand_path("tmp/fails_fixture_#{Process.pid}.md")
      # o que o `scripts/test` grava em tmp/fails.md e a saida do report
      report_body, err, status = run_script("fails-report", raw)
      assert status.success?, "exit #{status.exitstatus}: #{err}"
      File.write(report, report_body)
      out, err, status = run_script("fails-report", "--files", report)
      assert status.success?, "exit #{status.exitstatus}: #{err}"
      assert_equal "test/battle_routes_test.rb,test/team_routes_test.rb", out.strip
    ensure
      FileUtils.rm_f(report)
    end
  end

  private

  def run_script(name, *)
    Open3.capture3("bash", "scripts/#{name}", *)
  end

  # Fixture mora no teste (heredoc acima); materializa em tmp/ so na execucao.
  def with_raw_output(content)
    file = Tempfile.new(["fails-raw", ".txt"], File.expand_path("tmp"))
    file.write(content)
    file.close
    yield file.path
  ensure
    file&.unlink
  end
end
