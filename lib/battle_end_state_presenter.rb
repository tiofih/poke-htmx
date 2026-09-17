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

  # Lead da copy derivado do RESULTADO real da ultima batalha, nao do state:
  # vitoria => nil (copy "ganhou"); empate (KO duplo) => "Empate"; oponente
  # venceu => "Derrota" — inclusive no game over, onde o state e "over" mas o
  # resultado pode ter sido derrota ou empate. Rotulos vem de STATES (fonte unica).
  def reward_lead
    return nil if @engine.winner&.zero?

    @engine.winner.nil? ? STATES.fetch("draw")[:label] : STATES.fetch("loss")[:label]
  end

  # Sentenca completa da recompensa (fonte unica dos dois views): devolve nil
  # quando nao houve XP, senao o texto final montado.
  def reward_sentence(xp_gained:, money_gained:)
    xp = xp_gained.to_i
    return nil unless xp.positive?

    tail = money_gained ? " e +¥#{money_gained}." : "."
    lead = reward_lead
    lead ? "#{lead} — +#{xp} XP por Pokémon#{tail}" : "Seu Time ganhou #{xp} XP por Pokémon#{tail}"
  end
end
