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
    # Pins de dados duraveis valem so no disco local: graphify-out/ e
    # open-design/prints/ sao gitignored, o checkout de CI nao os tem.
    return unless File.directory?(File.join(repo_root, "graphify-out"))

    assert File.exist?(File.join(repo_root, "graphify-out/graph.json")), "graph.json e duravel, fica"
    assert File.exist?(File.join(repo_root, "open-design/prints")), "prints/ (sem backup/) fica"
  end

  # C2 — codigo Ruby morto ausente (§5.B): sem consumidor alem da definicao.
  def test_dead_ruby_helpers_removed
    server = File.read(File.join(repo_root, "server.rb"))
    generator = File.read(File.join(repo_root, "lib/opponent_generator.rb"))
    ["def base_form_names(", "def team_s_count(", "@team_s_count =",
     "def oob_battle_view\n", "def oob_battle_view "].each do |snippet|
      refute_includes server, snippet, "#{snippet.strip} morto (§5.B)"
    end
    ["def in_band?(", "def in_rating_band?("].each do |snippet|
      refute_includes generator, snippet, "#{snippet} morto (§5.B)"
    end
    assert_includes server, "def oob_battle_view_forced", "a _forced e viva (:788)"
  end

  # C3 — CSS morto ausente (§5.B), sem quebrar os pins vivos.
  def test_dead_css_removed
    raw = File.read(File.join(repo_root, "public/style.css"))
    css = raw.gsub(%r{/\*.*?\*/}m, "") # comentarios historicos ficam (:921, :2009)
    refute_match(/--jx-/, css, "familia --jx-* morta: nenhum var(--jx- em views/JS (§5.B)")
    assert_equal 1, css.scan(/@container \(min-width: 981px\)/).size,
                 "gate @container 981px duplicado deve restar 1"
    refute_match(/position:\s*static/, css, ".podium static morto (:610 vence por ordem)")
    refute_match(/\.mtags/, css, ".mtags morto (nenhuma view usa)")
    refute_match(/\.log-round\s*\{/, css, ".log-round solto morto (.log-round-head e vivo)")
    refute_match(/gameloop-cta/, css, "gameloop-cta morto (nenhuma view tem)")
    refute_match(/team-tools/, css, "team-tools .gameloop-cta morto")
    refute_match(/evolution-overlay|evolution-modal-box|evolution-modal-header|evolution-modal-close/,
                 css, "modal de evolucao antigo morto (markup usa #evolution-modal + .overlay.open)")
    refute_match(/fighter--flash|fighter--ko\b|fighter--shooting|\.projectile\b/, css,
                 "classes do reduce sem markup/JS emissor")

    # pins vivos que o apagamento nao pode tocar
    assert_match(/\.log-round-head\s*\{/, css, ".log-round-head e vivo")
    assert_match(/button[^{}]*\{[^}]*transition:/m, css, "transition de button viva")
    assert_match(/@keyframes\s+juice-shake/, css, "@keyframes juice vivos")
    assert_match(/\.evolution-row\s*\{/, css, ".evolution-row e vivo")
    assert_match(/\.ptags\s*\{/, css, ".ptags vira selector unico")
    assert_match(/\.log__entry\s*\{[^}]*--fx-color/m, raw, "bloco .log__entry mantem --fx-color")
  end

  # C4 — strike-log num unico partial (§5.C): battle.erb delega, partial aceita
  # log_delay e mantem o contrato de ordem de atributos.
  def test_battle_strike_log_uses_shared_partial
    battle = File.read(File.join(repo_root, "views/battle.erb"))
    partial = File.read(File.join(repo_root, "views/_strike_log_entry.erb"))

    refute_match(/<li class="log__entry"/, battle,
                 "battle.erb nao pode ter <li class=\"log__entry\" inline")
    assert_includes battle, "erb :_strike_log_entry",
                    "battle.erb delega o strike-log ao partial"
    assert_match(/log_delay/, partial, "partial aceita o local log_delay")
    assert_match(/data-round="[^"]*"[^>]*style="--log-delay:/m, partial,
                 "style depois de data-round (contrato battle_view_test.rb:244)")
  end

  # C5 — teste de history sem duplicata (§5.C): os contratos (.card--tight,
  # sem inline) vivem so em history_curation_test (test_history_matches_prototype).
  def test_duplicate_history_test_removed
    all_tests = Dir[File.join(repo_root, "test/*.rb")].map { |f| File.read(f) }
    occurrences = all_tests.count do |src|
      src.match?(/^\s*def test_history_cards_wear_tight_class_without_inline_style/)
    end
    assert_equal 0, occurrences,
                 "o teste duplicado saiu de history_view_test (contratos na curation)"
    curation = File.read(File.join(repo_root, "test/history_curation_test.rb"))
    assert_includes curation, 'body.scan(\'class="card card--tight"\').size',
                    "a cobertura restante fica em history_curation_test"
    assert_includes curation, 'refute_match(/class="card" style=/',
                    "a refutacao de inline fica em history_curation_test"
  end

  # C6 — citacoes penduradas corrigidas/anotadas em docs vivos (§5.D).
  # GDD.md e sessions/ sao symlinks para ../vaults (fora do repo); o vault so
  # existe na maquina local (compose monta ../vaults) — em CI sem vault as
  # leituras ficam inertes, os docs do repo (README/SESSIONS/docs/*) seguem
  # sempre cobertos.
  def read_live(path)
    File.read(path)
  rescue Errno::ENOENT
    nil
  end

  def test_dangling_citations_fixed_or_annotated
    gdd = read_live(File.join(repo_root, "GDD.md"))
    refute_includes gdd.to_s, "draft-futuro", "GDD.md nao cita mais draft-futuro (§5.D)"

    assert_absence_markers_on_live_docs
    assert_session_0086_lab_path
  end

  def assert_absence_markers_on_live_docs
    targets = %w[
      pending-spacing-replication-across-screens
      draft-futuro
      open-design-views-mockup
      draft-design-system
    ]
    markers = /ausente|removid|superseded/i
    live_docs = %w[GDD.md README.md REQUIREMENTS.md SESSIONS.md]
                .map { |f| File.join(repo_root, f) } +
                Dir[File.join(repo_root, "docs/*.md")]
    live_docs.each do |path|
      content = read_live(path)
      next if content.nil?

      content.each_line.with_index do |line, index|
        target = targets.find { |name| line.include?(name) }
        next unless target

        assert_match markers, line,
                     "#{File.basename(path)}:#{index + 1} cita #{target} sem marcador de ausencia"
      end
    end
  end

  def assert_session_0086_lab_path
    session = Dir[File.join(repo_root, "sessions/0086*.md")].first
    return if session.nil? # vault ausente (CI): sessions/ nao existe

    lab_lines = read_live(session).to_s.each_line.select { |line| line.include?("type-effects-lab") }
    refute_empty lab_lines, "sessions/0086 citado na §5.D precisa citar o lab"
    lab_lines.each do |line|
      assert_includes line, "docs/type-effects-lab.html",
                      "sessions/0086 aponta o caminho factual docs/ (§5.D)"
      refute_includes line, "public/type-effects-lab.html",
                      "o caminho antigo public/ sai de sessions/0086"
    end
  end
end
