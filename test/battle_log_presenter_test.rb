# frozen_string_literal: true

require "minitest/autorun"
require_relative "../lib/battle_log_presenter"

class BattleLogPresenterTest < Minitest::Test
  def attack_entry(round:, side:, attacker:, target:, move:, damage:, ko: false)
    { round: round, attacker: side, move_type: "electric", move: move, damage: damage,
      ko: ko, attacker_name: attacker, target_name: target }
  end

  def item_entry(round:, attacker:, item:, healed:)
    { round: round, attacker: 0, action: :item, item: item, healed: healed, attacker_name: attacker }
  end

  def test_empty_log_returns_empty_entries
    presenter = BattleLogPresenter.new([])

    assert_empty presenter.entries
  end

  def test_single_attack_entry_is_formatted_with_player_side
    log = [attack_entry(round: 1, side: 0, attacker: "pikachu", target: "squirtle", move: "thunder-shock", damage: 42)]
    presenter = BattleLogPresenter.new(log)

    entry = presenter.entries.first

    assert_equal 1, entry[:round]
    assert_equal "Seu Time", entry[:side]
    assert_equal "pikachu usou thunder-shock em squirtle, 42 de dano", entry[:text]
  end

  def test_attack_entry_from_opponent_uses_opponent_side
    log = [attack_entry(round: 1, side: 1, attacker: "squirtle", target: "pikachu", move: "water-gun", damage: 18)]
    presenter = BattleLogPresenter.new(log)

    assert_equal "Oponente", presenter.entries.first[:side]
  end

  def test_ko_attack_appends_ko_marker
    log = [attack_entry(round: 1, side: 0, attacker: "pikachu", target: "squirtle",
                        move: "thunder-shock", damage: 60, ko: true)]
    presenter = BattleLogPresenter.new(log)

    assert_includes presenter.entries.first[:text], " — KO!"
  end

  def test_item_entry_is_formatted_with_heal
    log = [item_entry(round: 1, attacker: "pikachu", item: "potion", healed: 20)]
    presenter = BattleLogPresenter.new(log)

    entry = presenter.entries.first

    assert_equal "Seu Time", entry[:side]
    assert_equal "pikachu usou Pocao, +20 HP", entry[:text]
  end

  def test_unknown_item_falls_back_to_raw_name
    log = [{ round: 1, attacker: 0, action: :item, item: "misterio", healed: 10, attacker_name: "pikachu" }]
    presenter = BattleLogPresenter.new(log)

    assert_equal "pikachu usou misterio, +10 HP", presenter.entries.first[:text]
  end

  def test_returns_only_last_three_rounds
    log = [
      attack_entry(round: 1, side: 0, attacker: "a", target: "b", move: "m1", damage: 5),
      attack_entry(round: 2, side: 0, attacker: "a", target: "b", move: "m2", damage: 5),
      attack_entry(round: 3, side: 0, attacker: "a", target: "b", move: "m3", damage: 5),
      attack_entry(round: 4, side: 0, attacker: "a", target: "b", move: "m4", damage: 5)
    ]
    presenter = BattleLogPresenter.new(log)

    assert_equal [4, 3, 2], presenter.entries.map { |entry| entry[:round] },
                 "mais recente no topo, limitado a 3 rodadas"
  end

  def test_entries_within_same_round_keep_order
    log = [
      attack_entry(round: 2, side: 0, attacker: "a", target: "b", move: "m1", damage: 5),
      attack_entry(round: 2, side: 1, attacker: "b", target: "a", move: "m2", damage: 5)
    ]
    presenter = BattleLogPresenter.new(log)

    names = presenter.entries.map { |entry| entry[:text].split.first }

    assert_equal %w[a b], names
  end

  def test_default_limit_is_three
    log = (1..5).map { |round| attack_entry(round: round, side: 0, attacker: "a", target: "b", move: "m", damage: 5) }
    presenter = BattleLogPresenter.new(log)

    assert_equal 3, presenter.entries.size
  end

  def test_entries_all_returns_every_round
    log = (1..5).map { |round| attack_entry(round: round, side: 0, attacker: "a", target: "b", move: "m", damage: 5) }
    presenter = BattleLogPresenter.new(log)

    assert_equal 5, presenter.entries_all.size,
                 "modo completo devolve todas as rodadas"
    assert_equal [5, 4, 3, 2, 1], presenter.entries_all.map { |entry| entry[:round] },
                 "mais recente no topo, sem limite"
  end

  def test_entries_include_from_to_side
    log = [
      attack_entry(round: 1, side: 0, attacker: "pikachu", target: "squirtle", move: "thunder-shock", damage: 42),
      attack_entry(round: 1, side: 1, attacker: "squirtle", target: "pikachu", move: "water-gun", damage: 18),
      item_entry(round: 1, attacker: "pikachu", item: "potion", healed: 20)
    ]
    presenter = BattleLogPresenter.new(log)

    entries = presenter.entries

    assert_equal 0, entries[0][:from_side], "ataque do jogador sai do lado 0"
    assert_equal 1, entries[0][:to_side], "ataque mira o lado oposto"
    assert_equal 1, entries[1][:from_side], "ataque do oponente sai do lado 1"
    assert_equal 0, entries[1][:to_side], "ataque do oponente mira o lado 0"
    assert_equal 0, entries[2][:from_side], "item cura o proprio lado"
    assert_equal 0, entries[2][:to_side], "item nao troca de lado (autocura)"
    assert_equal %i[round side text], entries[0].keys.first(3),
                 "contrato round/side/text preservado (backwards-compat)"
    assert_equal "Seu Time", entries[0][:side]
    assert_includes entries[0][:text], "42 de dano"
  end

  def test_entries_expose_slots_appended_last
    log = [attack_entry(round: 1, side: 0, attacker: "a", target: "b", move: "m", damage: 5)
      .merge(attacker_index: 1, target_index: 2)]
    entry = BattleLogPresenter.new(log).entries.first

    assert_equal 1, entry[:from_slot], "slot do atacante exposto no presenter (0088)"
    assert_equal 2, entry[:to_slot], "slot do alvo exposto no presenter (0088)"
    assert_equal %i[from_slot to_slot], entry.keys.last(2),
                 "chaves novas por ultimo (contrato de ordem preservado)"
  end

  def test_entries_tolerate_missing_slot_keys
    legacy = attack_entry(round: 1, side: 0, attacker: "a", target: "b", move: "m", damage: 5)
    entry = BattleLogPresenter.new([legacy]).entries.first

    assert_nil entry[:from_slot], "fake antigo sem a chave nao explode"
    assert_nil entry[:to_slot], "fake antigo sem a chave nao explode"
  end

  def test_entries_all_include_from_to_side
    log = [
      attack_entry(round: 1, side: 0, attacker: "a", target: "b", move: "m1", damage: 5),
      attack_entry(round: 2, side: 1, attacker: "b", target: "a", move: "m2", damage: 7),
      item_entry(round: 2, attacker: "a", item: "potion", healed: 10)
    ]
    presenter = BattleLogPresenter.new(log)

    all = presenter.entries_all

    assert_equal 3, all.size
    assert all.all? { |entry| [0, 1].include?(entry[:from_side]) },
           "toda entrada tem from_side 0/1"
    assert all.all? { |entry| [0, 1].include?(entry[:to_side]) },
           "toda entrada tem to_side 0/1"
    assert_equal({ round: 1, side: "Seu Time", text: "a usou m1 em b, 5 de dano", from_side: 0, to_side: 1 },
                 all.last.slice(:round, :side, :text, :from_side, :to_side),
                 "contrato completo preservado em entries_all")
  end

  def test_entries_grouped_by_round_newest_first
    log = [
      attack_entry(round: 1, side: 0, attacker: "a", target: "b", move: "m1", damage: 5),
      attack_entry(round: 2, side: 1, attacker: "b", target: "a", move: "m2", damage: 7),
      attack_entry(round: 2, side: 0, attacker: "a", target: "b", move: "m3", damage: 9)
    ]
    presenter = BattleLogPresenter.new(log)

    groups = presenter.groups_all

    assert_equal [2, 1], groups.map { |group| group[:round] }, "newest-first por rodada"
    assert_equal 2, groups.first[:entries].size, "entradas da rodada 2 agrupadas"
    assert_equal 1, groups.last[:entries].size, "entradas da rodada 1 agrupadas"
    assert groups.first[:entries].all? { |entry| entry[:round] == 2 },
           "cada entrada associada a sua rodada"
  end

  def test_entries_expose_damage_and_ko_for_chips
    log = [
      attack_entry(round: 1, side: 0, attacker: "a", target: "b", move: "m1", damage: 42, ko: true),
      item_entry(round: 1, attacker: "a", item: "potion", healed: 20)
    ]
    presenter = BattleLogPresenter.new(log)

    entries = presenter.entries

    assert_equal 42, entries[0][:damage], "chip de dano le do presenter"
    assert_equal true, entries[0][:ko], "chip de KO le do presenter"
    assert_nil entries[1][:damage], "item nao tem dano"
    assert_equal 20, entries[1][:healed], "item expoe cura"
  end

  def test_outcome_fields_exposes_move_type
    log = [
      attack_entry(round: 1, side: 0, attacker: "pikachu", target: "squirtle",
                   move: "thunder-shock", damage: 42),
      item_entry(round: 1, attacker: "pikachu", item: "potion", healed: 20)
    ]
    presenter = BattleLogPresenter.new(log)

    entries = presenter.entries

    assert_equal "electric", entries[0][:move_type],
                 "outcome_fields preserva o tipo do golpe (0086 C11)"
    assert_nil entries[1][:move_type],
               "linha sem golpe (item) nao carrega tipo — render omite o atributo"
  end

  def test_item_entries_with_stock_expose_remaining_and_last_unit
    log = [
      item_entry(round: 1, attacker: "pikachu", item: "potion", healed: 20),
      item_entry(round: 2, attacker: "pikachu", item: "potion", healed: 20)
    ]
    presenter = BattleLogPresenter.new(log, stock: { "potion" => 0 })

    entries = presenter.entries_all

    assert_equal 1, entries.last[:remaining], "primeiro uso: resta 1"
    assert_equal false, entries.last[:last_unit]
    assert_includes entries.last[:text], "restam 1"
    assert_equal 0, entries.first[:remaining], "segundo uso: estoque zerado"
    assert_equal true, entries.first[:last_unit]
    assert_includes entries.first[:text], "última unidade"
  end

  def test_item_entry_without_stock_keeps_legacy_copy
    log = [item_entry(round: 1, attacker: "pikachu", item: "potion", healed: 20)]
    presenter = BattleLogPresenter.new(log)

    entry = presenter.entries.first

    assert_nil entry[:remaining], "sem estoque: sem chave de restante"
    assert_nil entry[:last_unit], "sem estoque: sem flag de ultima unidade"
    assert_equal "pikachu usou Pocao, +20 HP", entry[:text], "copy legada preservada"
  end

  def test_attack_entries_have_no_stock_keys
    log = [attack_entry(round: 1, side: 0, attacker: "a", target: "b", move: "m1", damage: 5)]
    presenter = BattleLogPresenter.new(log, stock: { "potion" => 2 })

    entry = presenter.entries.first

    assert_nil entry[:remaining], "ataque nao carrega estoque"
    assert_nil entry[:last_unit], "ataque nao carrega flag"
  end
end
