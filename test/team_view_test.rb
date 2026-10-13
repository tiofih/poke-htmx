# frozen_string_literal: true

require "erb"
require "minitest/autorun"
require_relative "../lib/pokemon"
require_relative "../lib/team_presenter"
require_relative "../lib/team_repository"

# 0099 C1 — markup do fragmento de time fora dos testes de rota: renderiza
# views/team.erb com ERB stdlib + locals de TeamPresenter (puros, sem DB).
# Membros fake sao structs Pokemon reais (dry-struct) — exercitam fainted?,
# os cortes de bar-fill e o fetch(id.to_s, 1) de verdade.
class TeamViewTest < Minitest::Test
  TEMPLATE = ERB.new(File.read(File.join(__dir__, "../views/team.erb"))).freeze

  def build_member(name:, number:, id:, slot:, hp_max:, hp_current:)
    Pokemon.new(
      id: id, name: name, sprite: "https://example.com/#{name.downcase}.png",
      number: number, slot: slot, hp_max: hp_max, hp_current: hp_current
    )
  end

  def render_team(overrides = {})
    locals = {
      team: [], team_types: {}, member_levels: {},
      notice: nil, notice_kind: nil,
      can_battle: false, game_over: false, journey_started: true
    }.merge(overrides)
    TEMPLATE.result_with_hash(TeamPresenter.new(**locals).to_h)
  end

  def full_team
    (1..6).map do |n|
      build_member(name: "Mon#{n}", number: n, id: n, slot: n, hp_max: 100, hp_current: 100)
    end
  end

  def sample_roster
    [
      build_member(name: "Pikachu", number: 25, id: 1, slot: 1, hp_max: 100, hp_current: 70),
      build_member(name: "Bulbasaur", number: 1, id: 2, slot: 2, hp_max: 200, hp_current: 0),
      build_member(name: "Charmander", number: 4, id: 3, slot: 3, hp_max: 0, hp_current: 0),
      build_member(name: "Squirtle", number: 7, id: 4, slot: 4, hp_max: 100, hp_current: 35),
      build_member(name: "Pidgey", number: 16, id: 5, slot: 5, hp_max: 100, hp_current: 34),
      build_member(name: "Rattata", number: 19, id: 6, slot: 6, hp_max: 100, hp_current: 69)
    ]
  end

  def test_roster_renders_members_with_hp_levels_types_and_actions
    body = render_team(
      team: sample_roster,
      team_types: { 1 => %w[Electric], 2 => %w[Grass Poison] },
      member_levels: { "1" => 7 }
    )

    assert_equal 6, body.scan('<li class="member"').size, "um card por membro"
    assert_operator body.index("Pikachu"), :<, body.index("Bulbasaur"), "ordem de slot preservada"
    assert_roster_identity(body)
    assert_roster_hp_bars(body)
    assert_roster_actions(body)
  end

  def assert_roster_identity(body)
    assert_includes body, 'data-od-id="member-pikachu"', "data-od-id usa name.downcase"
    assert_includes body, "<span class=\"slot\">#1</span>", "badge de slot"
    assert_includes body, "<span class=\"member-name\">Pikachu</span>", "nome no card"
    assert_includes body, "Nível 7", "nivel vem de member_levels[id.to_s]"
    assert_equal 5, body.scan("Nível 1").size, "sem entrada em member_levels cai no default 1"
    assert_includes body, '<span class="mtag mtag--electric">Electric</span>', "tipos do team_types[id]"
    assert_includes body, '<span class="mtag mtag--grass">Grass</span>', "multiplos tipos"
    assert_equal 2, body.scan('<div class="tag-row">').size, "so quem tem tipos ganha tag-row"
  end

  def assert_roster_hp_bars(body)
    assert_includes body, "<span class=\"num hp-val\">70/100</span>", "HP real no card"
    assert_includes body, "<span class=\"num hp-val\">0/200</span>", "fainted mostra 0/max"
    assert_includes body, "<span class=\"num hp-val\">0/0</span>", "nunca lutou mostra 0/0"
    assert_includes body, '<span class="bar-fill" style="width:70%">', "0.7 nao e mid (corte exclusivo)"
    assert_includes body, '<span class="bar-fill low" style="width:0%">', "fainted e low"
    assert_equal 2, body.scan('<span class="bar-fill low" style="width:0%">').size,
                 "fainted e nunca-lutado dividem o low em 0% (a barra nao distingue)"
    assert_includes body, '<span class="bar-fill mid" style="width:35%">', "0.35 nao e low (corte exclusivo)"
    assert_includes body, '<span class="bar-fill low" style="width:34%">', "34% e low"
    assert_includes body, '<span class="bar-fill mid" style="width:69%">', "69% ainda e mid"
  end

  def assert_roster_actions(body)
    assert_includes body, 'hx-get="/team/1/manage"', "Gerenciar abre o modal do membro"
    assert_includes body, 'data-od-id="pikachu-manage"', "gerenciar com data-od-id"
    assert_includes body, 'data-od-id="pikachu-remove"', "remover com data-od-id"
    assert_includes body, 'aria-label="Mover para cima"', "reordenar p/ cima"
    assert_includes body, 'aria-label="Mover para baixo"', "reordenar p/ baixo"
    assert_includes body, 'name="new_slot" value="0"', "sobe do slot 1 p/ 0"
    assert_includes body, 'name="new_slot" value="2"', "desce do slot 1 p/ 2"
    assert_includes body, "disabled title=\"Pokémon derrotado — cure antes de remover\"",
                    "fainted desabilita Remover"
    assert_equal 1, body.scan(" disabled").size, "so o fainted desabilita (nunca-lutou nao e fainted)"
  end
end
