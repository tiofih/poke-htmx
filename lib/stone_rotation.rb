# frozen_string_literal: true

require_relative "item_catalog"

# Oferta da rodada de pedras de evolucao (D2 — derivada, sem banco).
# Seed = hash(user_id) + battle_count; shuffle determinístico tira 3 pedras.
class StoneRotation
  def initialize(user_id, battle_count = 0)
    @user_id = user_id
    @battle_count = battle_count
  end

  def stones
    seed = @user_id.hash + @battle_count
    stone_names.sample(3, random: Random.new(seed))
  end

  private

  def stone_names
    ItemCatalog.all.select { |item| item.category == "stone" }.map(&:name)
  end
end
