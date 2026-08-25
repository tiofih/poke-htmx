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
    missing = missing_hp(members)
    return full_notice if missing.zero?

    cost = @policy.cost(missing)
    balance = @wallet.balance(user_id)
    return insufficient_notice(cost, balance) if balance < cost

    heal_result(user_id, members, cost)
  end

  def preview_cost(user_id)
    @policy.cost(missing_hp(@team.all(user_id)))
  end

  private

  def missing_hp(members)
    members.sum { |member| @policy.missing_hp(member.hp_max, member.hp_current) }
  end

  def heal_result(user_id, members, cost)
    new_balance = charge_and_heal(user_id, members, cost)
    {
      healed: true,
      kind: :success,
      cost: cost,
      balance: new_balance,
      notice: "Time curado por #{cost} de dinheiro. Saldo: #{new_balance}."
    }
  end

  def charge_and_heal(user_id, members, cost)
    heal_members(user_id, members)
    @wallet.spend(user_id, cost)
  end

  def full_notice
    { healed: false, kind: :info, cost: 0, notice: "Seu time já está curado." }
  end

  def insufficient_notice(cost, balance)
    {
      healed: false,
      kind: :error,
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
