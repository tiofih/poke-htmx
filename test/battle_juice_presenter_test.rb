# frozen_string_literal: true

require "minitest/autorun"
require_relative "../lib/battle_juice_presenter"

class BattleJuicePresenterTest < Minitest::Test
  def attack_entry(round:, side:, attacker:, target:, move:, damage:, ko: false)
    { round: round, attacker: side, move_type: "electric", move: move, damage: damage,
      ko: ko, attacker_name: attacker, target_name: target }
  end

  def item_entry(round:, attacker:, item:, healed:)
    { round: round, attacker: 0, action: :item, item: item, healed: healed, attacker_name: attacker }
  end

  def test_initial_hp_derived_from_final_plus_damage_minus_heal
    log = [
      attack_entry(round: 1, side: 0, attacker: "pikachu", target: "squirtle", move: "thunder-shock", damage: 42),
      attack_entry(round: 2, side: 1, attacker: "squirtle", target: "pikachu", move: "water-gun", damage: 18),
      item_entry(round: 2, attacker: "pikachu", item: "potion", healed: 18)
    ]
    final_hp = { 0 => { "pikachu" => 202 }, 1 => { "squirtle" => 58 } }
    presenter = BattleJuicePresenter.new(log: log, final_hp: final_hp)

    assert_equal 202, presenter.initial_hp(0, "pikachu"),
                 "HP inicial = final (202) + dano sofrido (18) − cura (18)"
    assert_equal 100, presenter.initial_hp(1, "squirtle"),
                 "HP inicial = final (58) + dano sofrido (42) − cura (0)"
  end

  def test_initial_hp_without_entries_equals_final_hp
    presenter = BattleJuicePresenter.new(log: [], final_hp: { 0 => { "pikachu" => 202 } })

    assert_equal 202, presenter.initial_hp(0, "pikachu"),
                 "sem log (batalha nova) o HP inicial e o HP atual"
  end

  def test_derives_from_and_to_side_when_absent
    log = [attack_entry(round: 1, side: 1, attacker: "squirtle", target: "pikachu", move: "water-gun", damage: 18)]
    presenter = BattleJuicePresenter.new(log: log, final_hp: { 0 => { "pikachu" => 184 }, 1 => { "squirtle" => 100 } })

    assert_equal 1, presenter.from_side(log.first), "from_side derivado do attacker bruto"
    assert_equal 0, presenter.to_side(log.first), "to_side = lado oposto em ataque"
  end

  def test_fighter_juice_flags_damage_ko_and_shooting
    log = [
      attack_entry(round: 1, side: 0, attacker: "pikachu", target: "squirtle",
                   move: "thunder-shock", damage: 100, ko: true)
    ]
    final_hp = { 0 => { "pikachu" => 202 }, 1 => { "squirtle" => 0 } }
    presenter = BattleJuicePresenter.new(log: log, final_hp: final_hp)

    attacker = presenter.fighter_juice(0, "pikachu")
    assert_equal 202, attacker[:initial_hp]
    assert attacker[:shooting], "pikachu atacou — painel marca projétil"
    refute attacker[:damaged], "pikachu nao sofreu dano — sem flash"
    refute attacker[:ko], "pikachu nao desmaiou"

    target = presenter.fighter_juice(1, "squirtle")
    assert_equal 100, target[:initial_hp]
    assert target[:damaged], "squirtle sofreu dano — flash no alvo"
    assert target[:ko], "squirtle desmaiou — KO fade/grayscale"
    refute target[:shooting], "squirtle nao atacou — sem projétil"
  end

  def test_css_classes_map_juice_flags_to_style_hooks
    log = [
      attack_entry(round: 1, side: 0, attacker: "pikachu", target: "squirtle",
                   move: "thunder-shock", damage: 100, ko: true)
    ]
    final_hp = { 0 => { "pikachu" => 202, "pidgey" => 100 }, 1 => { "squirtle" => 0 } }
    presenter = BattleJuicePresenter.new(log: log, final_hp: final_hp)

    assert_equal ["is-attacking"], presenter.css_classes(0, "pikachu"),
                 "atacante veste o projetil (.shot via is-attacking)"
    assert_equal %w[fainted is-hit], presenter.css_classes(1, "squirtle").sort,
                 "alvo veste flash (is-hit) + KO (fainted)"
    assert_empty presenter.css_classes(0, "pidgey"),
                 "sem flags, sem classes de juice"
  end

  def test_css_classes_carry_no_timing_hooks
    log = [
      attack_entry(round: 1, side: 0, attacker: "pikachu", target: "squirtle",
                   move: "thunder-shock", damage: 100, ko: true)
    ]
    final_hp = { 0 => { "pikachu" => 202 }, 1 => { "squirtle" => 0 } }
    presenter = BattleJuicePresenter.new(log: log, final_hp: final_hp)

    # Passo 6 (0086): sincronia com o log vive no --step-delay do li
    # (view, max por lado) — classes seguem só booleanas, sem timing.
    all = presenter.css_classes(0, "pikachu") + presenter.css_classes(1, "squirtle")
    assert((all - %w[is-hit fainted is-attacking]).empty?,
           "juice veste só is-hit/fainted/is-attacking; --step-delay sincroniza o quando")
  end
end
