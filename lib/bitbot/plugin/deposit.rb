module Bitbot::Deposit
  def on_deposit(m, create = true)
    user_id = db.get_or_create_user_id_for_username(m.user.user)

    unless cached_addresses
      m.reply "Bitbot is not initialized yet. Please try again later."
      return
    end

    if address = cached_addresses[user_id]
      m.reply "Send deposits to #{address["address"].irc(:bold)}. " +
        "This address is specific to you, and any funds delivered " +
        "to it will be added to your account after confirmation."
      return
    end

    unless create
      m.reply "There was a problem getting your deposit address. " +
        "Please contact your friendly Bitbot admin."
      return
    end

    # Attempt to create an address.
    blockchain.create_deposit_address_for_user_id(user_id)

    # Force a refresh of the cached address list...
    on_update_addresses

    # Now run again, to show them the address we just looked up.
    on_deposit(m, false)
  end
end

