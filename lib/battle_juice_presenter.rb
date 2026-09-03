# frozen_string_literal: true

# Helper puro de juice da batalha (0063): deriva, por replay do log, o HP inicial
# de cada lutador (`hp_final + Σdano sofrido − Σcura`) e a origem/alvo (0/1) de
# cada entrada quando ausentes. Não toca engine/backend — só dados do log + HP final.
class BattleJuicePresenter
  def initialize(log:, final_hp:)
    @log = log
    @final_hp = final_hp # { 0 => { "nome" => hp }, 1 => { "nome" => hp } }
  end

  # HP inicial do lutador no começo da batalha: o HP final mais todo dano sofrido
  # menos toda cura recebida (replay — sem persistir estado extra).
  def initial_hp(side, name)
    final_hp(side, name) + damage_taken(side, name) - heal_received(side, name)
  end

  # Metadados de juice por lutador para a marcação do painel (C2): HP inicial,
  # se sofreu dano (flash), se desmaiou (KO) e se atacou (projétil).
  def fighter_juice(side, name)
    {
      initial_hp: initial_hp(side, name),
      damaged: damaged?(side, name),
      ko: fainted?(side, name),
      shooting: shooting?(side, name),
      damage_taken: damage_taken(side, name)
    }
  end

  def from_side(entry)
    entry[:from_side] || entry[:attacker].to_i
  end

  def to_side(entry)
    return entry[:to_side] if entry[:to_side]

    entry[:action] == :item ? from_side(entry) : 1 - from_side(entry)
  end

  private

  def damage_taken(side, name)
    @log.sum do |entry|
      next 0 if entry[:action] == :item
      next 0 unless to_side(entry) == side && entry[:target_name] == name

      entry[:damage].to_i
    end
  end

  def heal_received(side, name)
    @log.sum do |entry|
      next 0 unless entry[:action] == :item
      next 0 unless from_side(entry) == side && entry[:attacker_name] == name

      entry[:healed].to_i
    end
  end

  def damaged?(side, name)
    @log.any? do |entry|
      entry[:action] != :item && to_side(entry) == side && entry[:target_name] == name
    end
  end

  def fainted?(side, name)
    final_hp(side, name) <= 0
  end

  def shooting?(side, name)
    @log.any? do |entry|
      entry[:action] != :item && from_side(entry) == side && entry[:attacker_name] == name
    end
  end

  def final_hp(side, name)
    @final_hp.fetch(side, {}).fetch(name, 0).to_i
  end
end
