module Bitbot::Balance
  def on_balance(m)
    user_id = db.get_or_create_user_id_for_username(m.user.user)
    m.reply "Balance is #{satoshi_with_usd(db.get_balance_for_user_id(user_id))}"
  end
end

