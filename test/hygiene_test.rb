# frozen_string_literal: true

require_relative "test_helper"

# Higiene do repo (sessao 0093, draft §5.A-§5.D): lixo de disco, codigo e
# CSS mortos, strike-log deduplicado, teste de history sem duplicata e
# citacoes penduradas corrigidas. Um metodo por criterio (C1-C6).
class HygieneTest < Minitest::Test
  def repo_root
    File.expand_path("..", __dir__)
  end

  # C1 — nenhum cassette orfao: todo yml de test/cassettes/ tem o def
  # correspondente em algum arquivo de teste.
  def test_no_orphan_cassettes
    test_sources = Dir[File.join(repo_root, "test/*.rb")].map { |f| File.read(f) }.join("\n")
    Dir[File.join(repo_root, "test/cassettes/*/*.yml")].each do |cassette|
      test_name = File.basename(cassette, ".yml")
      assert_includes test_sources, "def #{test_name}",
                      "cassette #{File.basename(File.dirname(cassette))}/#{File.basename(cassette)} orfao"
    end
  end

  # C1 — lixo local estavel (nao-regeneravel) fora do disco. Os regeneraveis
  # (tmp/*_cache.json, .zvec-grep/, graphify-out/cache/, test-results/,
  # .DS_Store, _ai_context/legacy/) nao tem pin: reflariam por ambiente
  # (sessao 0093 §8) — apagados no passo com `test ! -e` + du no commit.
  def test_stable_junk_removed_from_disk
    %w[
      refs
      landing
      open-design/prints/backup-2026-09-10
      _temp_notes.md
    ].each do |path|
      refute File.exist?(File.join(repo_root, path)), "#{path} devia ter sido apagado (§5.A)"
    end
    assert File.exist?(File.join(repo_root, "graphify-out/graph.json")), "graph.json e duravel, fica"
    assert File.exist?(File.join(repo_root, "open-design/prints")), "prints/ (sem backup/) fica"
  end
end
