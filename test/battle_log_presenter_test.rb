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
end
