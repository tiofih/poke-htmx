# frozen_string_literal: true

class SellPolicy
  def sell_price(item)
    item.price / 2
  end
end
