# frozen_string_literal: true

require_relative "test_helper"

class PokeApiTest < Minitest::Test
  def fifteen_names
    %w[bulbasaur ivysaur venusaur charmander charmeleon charizard squirtle wartortle
       blastoise caterpie metapod butterfree pikachu pikachu-raichu raichu]
  end

  def test_paginate_returns_names_for_offset_with_total
    PokeApiStub.with_all_names(fifteen_names) do
      page = PokeApi.paginate(offset: 0, limit: 10)

      assert_equal 10, page[:names].size
      assert_equal 15, page[:total]
      assert_equal "bulbasaur", page[:names].first
    end
  end

  def test_paginate_slices_by_offset
    PokeApiStub.with_all_names(fifteen_names) do
      page = PokeApi.paginate(offset: 10, limit: 10)

      assert_equal 5, page[:names].size
      assert_equal %w[pikachu pikachu-raichu raichu], page[:names][2..]
      assert_equal 15, page[:total]
    end
  end

  def test_paginate_returns_empty_when_offset_beyond_end
    PokeApiStub.with_all_names(fifteen_names) do
      page = PokeApi.paginate(offset: 100, limit: 10)

      assert_empty page[:names]
      assert_equal 15, page[:total]
    end
  end

  def test_paginate_filters_by_substring_case_insensitive
    PokeApiStub.with_all_names(fifteen_names) do
      page = PokeApi.paginate(offset: 0, limit: 10, q: "PIK")

      assert_equal %w[pikachu pikachu-raichu], page[:names]
      assert_equal 2, page[:total]
    end
  end

  def test_paginate_with_empty_q_returns_all
    PokeApiStub.with_all_names(fifteen_names) do
      page = PokeApi.paginate(offset: 0, limit: 100, q: "")

      assert_equal 15, page[:names].size
      assert_equal 15, page[:total]
    end
  end

  def test_paginate_filters_then_paginates
    PokeApiStub.with_all_names(fifteen_names) do
      first = PokeApi.paginate(offset: 0, limit: 1, q: "char")
      second = PokeApi.paginate(offset: 1, limit: 1, q: "char")

      assert_equal %w[charmander], first[:names]
      assert_equal %w[charmeleon], second[:names]
      assert_equal 3, second[:total]
    end
  end
end