# frozen_string_literal: true

require "minitest/autorun"
require_relative "../lib/mart_presenter"

class MartPresenterTest < Minitest::Test
  def build(overrides = {})
    {
      balance: 500, catalog: [], inventory: {}, rotation: []
    }.merge(overrides)
  end

  def test_to_h_has_exactly_the_six_locals_of_the_mart_modal
    assert_equal %i[notice notice_kind balance catalog inventory rotation],
                 MartPresenter.new(**build).to_h.keys
  end

  def test_passes_resolved_data_through_unchanged
    data = build(
      notice: "Compra efetuada.", notice_kind: :success, balance: 120,
      catalog: [{ name: "potion" }], inventory: { "potion" => 2 }, rotation: ["potion"]
    )

    assert_equal data, MartPresenter.new(**data).to_h
  end

  def test_notice_defaults_to_nil_when_route_set_none
    to_h = MartPresenter.new(**build).to_h

    assert_nil to_h[:notice]
    assert_nil to_h[:notice_kind]
  end

  def test_requires_the_data_the_view_needs
    assert_raises(ArgumentError) { MartPresenter.new(notice: nil) }
  end
end
