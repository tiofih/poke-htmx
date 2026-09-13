#!/usr/bin/env ruby
# frozen_string_literal: true

# rubocop:disable Style/FormatStringToken, Naming/VariableNumber

# sweep-balance.rb — estilo RuleSmith, sem chave e sem DB: varia os parâmetros
# de RewardRule + taxa de vitória e projeta a economia (XP/nível/dinheiro).
# Roda no HOST: ruby scripts/sweep-balance.rb (puro, sem gems, seed fixa).
# Uso: ao propor tuning (sessão de balanceamento), rode e cole a tabela.

require_relative "../lib/reward_rule"
require_relative "../lib/experience_curve"

SEED = 42
BATTLES = 200
WIN_RATES = [0.3, 0.5, 0.7].freeze
VARIANTS = {
  "default" => {},
  "stingy-money" => { win_money: 50, draw_money: 25, lose_money: 20 },
  "rich-xp" => { win_xp: 75, draw_xp: 35, lose_xp: 30 }
}.freeze

def simulate(rule, win_rate, rng) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
  xp = 0
  money = 0
  to_lvl5 = nil
  to_lvl10 = nil
  BATTLES.times do |i|
    r = rng.rand
    result = if r < win_rate
               :win
             elsif r < win_rate + 0.15
               :draw
             else
               :lose
             end
    xp += rule.xp_for(result)
    money += rule.money_for(result)
    lvl = ExperienceCurve.level_for_xp(xp)
    to_lvl5 ||= i + 1 if lvl >= 5
    to_lvl10 ||= i + 1 if lvl >= 10
  end
  { battles_to_5: to_lvl5 || ">#{BATTLES}", battles_to_10: to_lvl10 || ">#{BATTLES}",
    money: money, money_per_battle: (money.to_f / BATTLES).round(1) }
end

puts "level | xp_needed | cumulativo"
(1..12).each do |lv|
  puts format("%5d | %9d | %10d", lv, ExperienceCurve.xp_needed(lv), ExperienceCurve.cumulative_xp_for(lv))
end
puts "\nvariante | win_rate | batalhas→nv5 | batalhas→nv10 | dinheiro | ¥/batalha"
VARIANTS.each do |name, opts|
  rule = RewardRule.new(opts)
  WIN_RATES.each do |p|
    s = simulate(rule, p, Random.new(SEED))
    puts format("%-12s | %.1f | %12s | %13s | %8d | %9s",
                name, p, s[:battles_to_5], s[:battles_to_10], s[:money], s[:money_per_battle])
  end
end

# farejo de estratégia dominante (lente Optimizer do cabal): perder de propósito paga quanto?
rr = RewardRule.new
lose_xp = rr.xp_for(:lose)
win_xp = rr.xp_for(:win)
puts "\nloser-farming: derrota rende #{lose_xp} XP vs #{win_xp} da vitoria " \
     "(#{(lose_xp * 100.0 / win_xp).round(0)}%). Se batalha durar o mesmo tempo, vencer domina " \
     "#{(win_xp.to_f / lose_xp).round(1)}x — sem exploit aqui."

# rubocop:enable Style/FormatStringToken, Naming/VariableNumber
