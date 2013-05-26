module Bitbot::History
  def on_history(m)
    user_id = db.get_or_create_user_id_for_username(m.user.user)

    on_balance(m)

    n = 0
    db.get_transactions_for_user_id(user_id).each do |tx|
      time = Time.at(tx[:created_at].to_i).strftime("%Y-%m-%d")
      amount = satoshi_with_usd(tx[:amount])
      action = if tx[:amount] < 0 && tx[:other_user_id]
                 "to #{tx[:other_username]}"
               elsif tx[:amount] > 0 && tx[:other_user_id]
                 "from #{tx[:other_username]}"
               elsif tx[:withdrawal_address]
                 "withdrawal to #{tx[:withdrawal_address]}"
               elsif tx[:incoming_transaction]
                 "deposit from tx #{tx[:incoming_transaction]}"
               end

      m.reply "#{time.irc(:grey)}: #{amount} #{action} #{"(#{tx[:note]})".irc(:grey) if tx[:note]}"

      n += 1
      break if n >= 10
    end
  end
end
