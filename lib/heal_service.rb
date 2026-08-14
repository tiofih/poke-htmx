# frozen_string_literal: true

require_relative "heal_cost_policy"

class HealService
  def initialize(team:, progression:, wallet:, policy: HealCostPolicy.new)
    @team = team
    @progression = progression
    @wallet = wallet
    @policy = policy
  end

  def heal(user_id)
    members = @team.all(user_id)
    missing = members.sum { |member| @policy.missing_hp(member.hp_max, member.hp_current) }
    return full_notice if missing.zero?

    cost = @policy.cost(missing)
    balance = @wallet.balance(user_id)
    return insufficient_notice(cost, balance) if balance < cost

    heal_members(user_id, members)
    new_balance = @wallet.spend(user_id, cost)
    {
      healed: true,
      cost: cost,
      balance: new_balance,
      notice: "Time curado por #{cost} de dinheiro. Saldo: #{new_balance}."
    }
  end

  private

  def full_notice
    { healed: false, cost: 0, notice: "Seu time já está curado." }
  end

  def insufficient_notice(cost, balance)
    {
      healed: false,
      cost: cost,
      balance: balance,
      notice: "Dinheiro insuficiente para curar (custo #{cost}, saldo #{balance})."
    }
  end

  def heal_members(user_id, members)
    members.each do |member|
      next if member.hp_max.to_i <= 0

      @progression.update_hp(user_id, member.id, member.hp_max, member.hp_max)
    end
  end
end
