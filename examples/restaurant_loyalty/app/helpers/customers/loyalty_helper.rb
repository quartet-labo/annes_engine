module Customers
  module LoyaltyHelper
    def points_label(points)
      "#{points.to_i} pt"
    end

    def entry_type_label(entry)
      {
        "earn" => "付与",
        "redeem" => "利用",
        "expire" => "失効",
        "adjust" => "調整",
        "reverse" => "取消"
      }.fetch(entry.entry_type, entry.entry_type)
    end
  end
end
