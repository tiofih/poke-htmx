# frozen_string_literal: true

require "minitest/autorun"
require_relative "../lib/team_presenter"

class TeamPresenterTest < Minitest::Test
  def build(overrides = {})
    {
      team: [], team_types: {}, member_levels: {},
      notice: nil, notice_kind: nil,
      can_battle: false, game_over: false, journey_started: false
    }.merge(overrides)
  end

  def test_to_h_has_exactly_the_eight_locals_of_the_team_fragment
    assert_equal %i[team team_types member_levels notice notice_kind can_battle game_over journey_started],
                 TeamPresenter.new(**build).to_h.keys
  end

  def test_passes_resolved_data_through_unchanged
    data = build(
      team: ["bulbasaur"], team_types: { "bulbasaur" => %w[grass poison] },
      member_levels: { "1" => 5 }, notice: "Time atualizado.", notice_kind: :success,
      can_battle: true, game_over: false, journey_started: true
    )

    assert_equal data, TeamPresenter.new(**data).to_h
  end

  def test_notice_defaults_to_nil_when_route_set_none
    to_h = TeamPresenter.new(**build).to_h

    assert_nil to_h[:notice]
    assert_nil to_h[:notice_kind]
  end

  def test_requires_the_data_the_view_needs
    assert_raises(ArgumentError) { TeamPresenter.new(team: []) }
  end
end
