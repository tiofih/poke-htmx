# frozen_string_literal: true

require "minitest/autorun"
require_relative "../lib/battle_pokemon"
require_relative "../lib/fighter_presenter"
require_relative "../lib/item_catalog"

class FighterPresenterTest < Minitest::Test
  def build_fighter(hp_current:, hp_max:, moves: [], assigned_item: nil, held_item: nil)
    BattlePokemon.new(
      number: 25,
      name: "pikachu",
      sprite: "https://example.com/pikachu.png",
      types: ["electric"],
      stats: [{ name: "HP", value: hp_max }],
      hp_max: hp_max,
      hp_current: hp_current,
      moves: moves,
      level: 5,
      assigned_item: assigned_item,
      held_item: held_item
    )
  end

  def build_move(pp:, pp_max: nil)
    Move.new(name: "thunder-shock", type: "electric", power: 40, accuracy: 100, pp: pp, pp_max: pp_max)
  end

  def test_presenter_exposes_fighter_identity
    presenter = FighterPresenter.new(build_fighter(hp_current: 100, hp_max: 200))

    assert_equal "pikachu", presenter.name
    assert_equal 5, presenter.level
    assert_equal "https://example.com/pikachu.png", presenter.sprite
    assert_equal "pikachu", presenter.alt
  end

  def test_hp_percent_is_rounded_share_of_current_over_max
    presenter = FighterPresenter.new(build_fighter(hp_current: 150, hp_max: 200))

    assert_equal 75, presenter.hp_percent
  end

  def test_hp_tier_high_when_half_or_more
    presenter = FighterPresenter.new(build_fighter(hp_current: 100, hp_max: 200))

    assert_equal :high, presenter.hp_tier
  end

  def test_hp_tier_medium_between_20_and_49_percent
    presenter = FighterPresenter.new(build_fighter(hp_current: 60, hp_max: 200))

    assert_equal :medium, presenter.hp_tier
  end

  def test_hp_tier_low_below_20_percent
    presenter = FighterPresenter.new(build_fighter(hp_current: 20, hp_max: 200))

    assert_equal :low, presenter.hp_tier
  end

  def test_hp_percent_zero_when_max_is_zero
    presenter = FighterPresenter.new(build_fighter(hp_current: 0, hp_max: 0))

    assert_equal 0, presenter.hp_percent
  end

  def test_moves_expose_pp_current_and_percent
    move = build_move(pp: 30, pp_max: 30)
    presenter = FighterPresenter.new(build_fighter(hp_current: 200, hp_max: 200, moves: [move]))

    move_presenter = presenter.moves.first

    assert_equal "thunder-shock", move_presenter.name
    assert_equal 30, move_presenter.pp_current
    assert_equal 30, move_presenter.pp_max
    assert_equal 100, move_presenter.pp_percent
  end

  def test_move_pp_percent_reflects_spent_pp
    move = build_move(pp: 15, pp_max: 30)
    presenter = FighterPresenter.new(build_fighter(hp_current: 200, hp_max: 200, moves: [move]))

    assert_equal 50, presenter.moves.first.pp_percent
  end

  def test_move_pp_tier_follows_same_thresholds
    high = build_move(pp: 30, pp_max: 30)
    medium = build_move(pp: 12, pp_max: 30)
    low = build_move(pp: 5, pp_max: 30)
    presenter = FighterPresenter.new(build_fighter(hp_current: 200, hp_max: 200, moves: [high, medium, low]))

    assert_equal %i[high medium low], presenter.moves.map(&:pp_tier)
  end

  def test_pp_max_defaults_to_pp_when_absent
    move = build_move(pp: 30)
    presenter = FighterPresenter.new(build_fighter(hp_current: 200, hp_max: 200, moves: [move]))

    assert_equal 30, presenter.moves.first.pp_max
  end

  def test_assigned_and_held_items_use_display_name
    presenter = FighterPresenter.new(
      build_fighter(hp_current: 200, hp_max: 200, assigned_item: "potion", held_item: "choice-band")
    )

    assert_equal "Pocao", presenter.assigned_item_label
    assert_equal "Choice Band", presenter.held_item_label
  end

  def test_unknown_item_falls_back_to_raw_name
    presenter = FighterPresenter.new(
      build_fighter(hp_current: 200, hp_max: 200, assigned_item: "misterio")
    )

    assert_equal "misterio", presenter.assigned_item_label
  end

  def test_fighter_without_items_has_empty_labels
    presenter = FighterPresenter.new(build_fighter(hp_current: 200, hp_max: 200))

    assert_nil presenter.assigned_item_label
    assert_nil presenter.held_item_label
  end

  def test_item_used_defaults_false
    presenter = FighterPresenter.new(build_fighter(hp_current: 200, hp_max: 200))

    refute presenter.item_used?
    assert_nil presenter.item_used_badge
  end

  def test_item_used_badge_when_flagged
    presenter = FighterPresenter.new(build_fighter(hp_current: 200, hp_max: 200), item_used: true)

    assert presenter.item_used?
    assert_equal "já usou item", presenter.item_used_badge
  end
end
