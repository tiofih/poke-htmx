# frozen_string_literal: true

require_relative "item_catalog"

class FighterPresenter
  def initialize(pokemon, item_used: false)
    @pokemon = pokemon
    @item_used = item_used
  end

  def name
    @pokemon.name
  end

  def level
    @pokemon.level
  end

  def sprite
    @pokemon.sprite
  end

  def alt
    @pokemon.name
  end

  def hp_percent
    return 0 if @pokemon.hp_max.to_i <= 0

    ((@pokemon.hp_current.to_f / @pokemon.hp_max) * 100).round
  end

  def hp_tier
    tier_for(hp_percent)
  end

  def hp_label
    "#{@pokemon.hp_current}/#{@pokemon.hp_max}"
  end

  def moves
    @pokemon.moves.map { |move| MovePresenter.new(move) }
  end

  def types
    @pokemon.types.to_a
  end

  def assigned_item_label
    item_label(@pokemon.assigned_item)
  end

  def held_item_label
    item_label(@pokemon.held_item)
  end

  def item_used?
    @item_used
  end

  def item_used_badge
    "já usou item" if item_used?
  end

  private

  def item_label(item_name)
    return nil if item_name.nil? || item_name.to_s.empty?

    ItemCatalog.find(item_name)&.display_name || item_name
  end

  def tier_for(percent)
    return :low if percent < 20
    return :medium if percent < 50

    :high
  end

  class MovePresenter
    def initialize(move)
      @move = move
    end

    def name
      @move.name
    end

    def pp_current
      @move.pp
    end

    def pp_max
      @move.pp_max
    end

    def pp_percent
      return 0 if pp_max.to_i <= 0

      ((pp_current.to_f / pp_max) * 100).round
    end

    def pp_tier
      percent = pp_percent
      return :low if percent < 20
      return :medium if percent < 50

      :high
    end
  end
end
