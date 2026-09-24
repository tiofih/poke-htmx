# frozen_string_literal: true

require_relative "test_helper"

# Contrato estrutural da sessao 0096 (render_oob + locals explicitos):
# pinos C1-C4 do plano. Um metodo por criterio. Os pins de bytes
# (ordem id= antes de hx-swap-oob=) vivem nos testes de rota ja verdes.
class ViewContractTest < Minitest::Test
  def repo_root
    File.expand_path("..", __dir__)
  end

  # Fonte verdadeira: um metodo = um criterio.
  def server_source
    File.read(File.join(repo_root, "server.rb"))
  end

  def view_sources
    Dir[File.join(repo_root, "views/*.erb")].to_h { |f| [File.basename(f), File.read(f)] }
  end

  # C1 — nenhuma convencao legada de OOB: sem .sub() manual em server.rb,
  # sem o wrapper de hack views/team_view_oob.erb, e com render_oob/oob_wrap
  # vivos no ServerCommon.
  def test_server_has_no_sub_based_oob
    # a implementacao canonica do render_oob usa .sub(id=) — sai da varredura
    fora_da_helper = server_source.sub(/def render_oob\(.*?\n  end/m, "")
    refute_match(/\.sub\(%\(id="|\.sub\('id="/, fora_da_helper,
                 "hack .sub de OOB voltou; use render_oob (sessao 0096)")
    refute File.exist?(File.join(repo_root, "views/team_view_oob.erb")),
           "wrapper de hack team_view_oob.erb foi apagado no passo 1"
    assert_includes server_source, "def render_oob(", "render_oob e a convencao unica"
    assert_includes server_source, "def oob_wrap(", "oob_wrap e a convencao unica"
  end

  # C2 — nenhuma view contem guarda defined? (a de @team_size vive so em
  # layout.erb, tratada no C3 como excecao de ivar).
  def test_views_have_no_defined_guards
    view_sources.each do |name, source|
      refute_match(/defined\?/, source,
                   "views/#{name} tem guarda defined?; passe o local explicito (sessao 0096)")
    end
  end

  # C3 — nenhuma view le ivar @x, exceto layout.erb (@team_size, decidido
  # no refinamento: layout roda com render_views -> @team_size do route.rb).
  def test_views_have_no_ivars_except_layout
    view_sources.each do |name, source|
      next if name == "layout.erb"

      refute_match(/@[a-z_][a-z0-9_]*/, source,
                   "views/#{name} le ivar; use locals: (sessao 0096)")
    end
  end

  # C4 — toda chamada erb em server.rb e em views/ declara locals:. O chunk e
  # a linha do match + linhas seguintes enquanto a anterior termina em , ( { [
  # (continuacao multiline); comentario de linha (#, <%#) e ignorado.
  def test_erb_calls_declare_locals
    sources = { "server.rb" => server_source }.merge(view_sources)
    offenders = []

    sources.each do |name, source|
      source.to_enum(:scan, /(?<!\.)\berb\b/).each do
        chunk = erb_call_chunk(source, Regexp.last_match.begin(0))
        next if chunk.nil? || chunk.include?("locals:")

        offenders << "#{name}: #{chunk.gsub(/\s+/, ' ')}"
      end
    end

    assert_empty offenders,
                 "chamada erb sem locals: — orquestracao vira contrato de keyword " \
                 "(sessao 0096):\n#{offenders.join("\n")}"
  end

  # Linhas da chamada erb a partir da posicao do match (ver comentario do C4).
  def erb_call_chunk(source, pos)
    prefix = source[0...pos][/[^\n]*\z/]
    return nil if prefix.match?(/\A\s*#/) || prefix.include?("<%#")

    chunk = +""
    source[pos..].each_line do |line|
      chunk << line
      break unless line.chomp.end_with?(",", "(", "{", "[")
    end
    chunk
  end
end
