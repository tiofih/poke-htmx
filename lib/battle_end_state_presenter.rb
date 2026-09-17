# frozen_string_literal: true

# Fonte unica do estado de fim de batalha (0089 Passo 8): slug/label/titulo do
# estado, vencedor do badge e o lead da copy de recompensa saem daqui, para o
# modal do strike (_strike_result.erb) e o render full (battle.erb) nao
# divergirem. Engine e regras de economia ficam read-only; isto e so apresentacao.
class BattleEndStatePresenter
  # win/loss/draw = vencedor do engine; over = game over (@game_over: time
  # derrotado e sem dinheiro para curar).
  STATES = {
    "win" => { slug: "victory", label: "Vitória", title: "Seu Time venceu" },
    "loss" => { slug: "defeat", label: "Derrota", title: "Oponente venceu" },
    "draw" => { slug: "draw", label: "Empate", title: "Empate — ninguém venceu" },
    "over" => { slug: "gameover", label: "Game Over", title: "Sem dinheiro para curar" }
  }.freeze

  # Lead da copy de recompensa por estado; ausente (vitoria) => copy "ganhou".
  # over e loss partilham "Derrota" mesmo com badges diferentes (badge usa o
  # vencedor real do engine).
  REWARD_LEADS = { "loss" => "Derrota", "over" => "Derrota", "draw" => "Empate" }.freeze

  def initialize(engine, game_over:)
    @engine = engine
    @game_over = game_over
  end

  def state
    return "over" if @game_over
    return "draw" if @engine.winner.nil?

    @engine.winner.zero? ? "win" : "loss"
  end

  def slug
    STATES.fetch(state)[:slug]
  end

  def label
    STATES.fetch(state)[:label]
  end

  def title
    STATES.fetch(state)[:title]
  end

  def winner_name
    return nil if @engine.winner.nil?

    @engine.winner.zero? ? "Seu Time" : "Oponente"
  end

  def reward_lead
    REWARD_LEADS[state]
  end
end
