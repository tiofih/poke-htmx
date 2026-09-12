# frozen_string_literal: true

require_relative "item_catalog"

class BattleLogPresenter # rubocop:disable Metrics/ClassLength
  DEFAULT_LIMIT = 3

  def initialize(log, limit: DEFAULT_LIMIT, stock: nil)
    @log = log
    @limit = limit
    @stock = stock
    @remaining_after = remaining_map
  end

  def entries
    recent_rounds.flat_map { |round| entries_for_round(round) }
  end

  def entries_all
    @log.map { |entry| entry[:round] }.uniq.sort.reverse.flat_map { |round| entries_for_round(round) }
  end

  def groups
    recent_rounds.map { |round| { round: round, entries: entries_for_round(round) } }
  end

  def groups_all
    @log.map { |entry| entry[:round] }.uniq.sort.reverse.map do |round|
      { round: round, entries: entries_for_round(round) }
    end
  end

  # Single-entry render for per-strike append (0086 pedra fundamental:
  # 1 strike = 1 linha). Locates the entry's index for stock copy.
  def format_single(entry)
    index = @log.rindex { |item| item.equal?(entry) } || @log.rindex(entry)
    format_entry(entry, index)
  end

  private

  def recent_rounds
    @log.map { |entry| entry[:round] }.uniq.sort.last(@limit).reverse
  end

  def entries_for_round(round)
    @log.each_with_index.select { |entry, _| entry[:round] == round }.map do |entry, index|
      format_entry(entry, index)
    end
  end

  def format_entry(entry, index = nil)
    {
      round: entry[:round],
      side: side_label(entry),
      text: entry_text(entry, index),
      from_side: from_side(entry),
      to_side: to_side(entry)
    }.merge(outcome_fields(entry)).merge(stock_fields(index))
  end

  def outcome_fields(entry)
    { damage: entry[:damage], ko: entry[:ko] || false, healed: entry[:healed] }
  end

  def entry_text(entry, index)
    return format_attack(entry) unless entry[:action] == :item

    format_item(entry, remaining_at(index))
  end

  def remaining_at(index)
    @remaining_after[index] unless index.nil?
  end

  def stock_fields(index)
    remaining = remaining_at(index)
    return { remaining: nil, last_unit: nil } if remaining.nil?

    { remaining: remaining, last_unit: remaining.zero? }
  end

  # Origem/alvo (0 = Seu Time, 1 = Oponente) derivados do log bruto: ataque sai
  # do lado do atacante e mira o lado oposto; item cura o proprio lado (0063 juice).
  def from_side(entry)
    entry[:from_side] || entry[:attacker].to_i
  end

  def to_side(entry)
    return entry[:to_side] if entry[:to_side]

    entry[:action] == :item ? from_side(entry) : 1 - from_side(entry)
  end

  def side_label(entry)
    entry[:attacker].zero? ? "Seu Time" : "Oponente"
  end

  def format_attack(entry)
    move = entry[:move] || entry[:move_type]
    text = "#{entry[:attacker_name]} usou #{move} em #{entry[:target_name]}, #{entry[:damage]} de dano"
    entry[:ko] ? "#{text} — KO!" : text
  end

  def format_item(entry, remaining = nil)
    display = ItemCatalog.find(entry[:item])&.display_name || entry[:item]
    text = "#{entry[:attacker_name]} usou #{display}, +#{entry[:healed]} HP"
    return text if remaining.nil?

    text = "#{entry[:attacker_name]} usou 1 #{display}, +#{entry[:healed]} HP — restam #{remaining}"
    remaining.zero? ? "#{text} (última unidade)" : text
  end

  # Estoque restante apos cada uso (0086 C3): replay a partir do estoque final
  # (engine.items) + usos posteriores no log. Sem engine, sem mudar o log.
  def remaining_map
    return {} if @stock.nil?

    totals = use_totals
    seen = Hash.new(0)
    @log.each_with_index.with_object({}) do |(entry, index), map|
      next unless entry[:action] == :item

      key = item_key(entry)
      seen[key] += 1
      map[index] = stock_for(key) + (totals[key] - seen[key])
    end
  end

  def use_totals
    @log.each_with_object(Hash.new(0)) do |entry, totals|
      totals[item_key(entry)] += 1 if entry[:action] == :item
    end
  end

  def item_key(entry)
    entry[:item].to_s
  end

  def stock_for(key)
    return @stock[key].to_i if @stock.key?(key)
    return @stock[key.to_sym].to_i if @stock.key?(key.to_sym)

    0
  end
end
