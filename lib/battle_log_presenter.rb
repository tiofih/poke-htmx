# frozen_string_literal: true

require_relative "item_catalog"

class BattleLogPresenter
  DEFAULT_LIMIT = 3

  def initialize(log, limit: DEFAULT_LIMIT)
    @log = log
    @limit = limit
  end

  def entries
    recent_rounds.flat_map { |round| entries_for_round(round) }
  end

  private

  def recent_rounds
    @log.map { |entry| entry[:round] }.uniq.sort.last(@limit).reverse
  end

  def entries_for_round(round)
    @log.select { |entry| entry[:round] == round }.map { |entry| format_entry(entry) }
  end

  def format_entry(entry)
    {
      round: entry[:round],
      side: side_label(entry),
      text: entry[:action] == :item ? format_item(entry) : format_attack(entry)
    }
  end

  def side_label(entry)
    entry[:attacker].zero? ? "Seu Time" : "Oponente"
  end

  def format_attack(entry)
    move = entry[:move] || entry[:move_type]
    text = "#{entry[:attacker_name]} usou #{move} em #{entry[:target_name]}, #{entry[:damage]} de dano"
    entry[:ko] ? "#{text} — KO!" : text
  end

  def format_item(entry)
    display = ItemCatalog.find(entry[:item])&.display_name || entry[:item]
    "#{entry[:attacker_name]} usou #{display}, +#{entry[:healed]} HP"
  end
end
