# coding: utf-8

module Bitbot::Tip
  def on_tip(m, recipient, amount, message)
    # Look up sender
    user_id = db.get_or_create_user_id_for_username(m.user.user)

    # Look up recipient
    recipient_ircuser = m.channel.users.keys.find {|u| u.name == recipient }
    unless recipient_ircuser
      m.user.msg("Could not find #{recipient} in the channel list.")
      return
    end
    recipient_user_id = db.get_or_create_user_id_for_username(recipient_ircuser.user)

    # Convert amount to satoshi
    satoshi = str_to_satoshi(amount)
    if satoshi <= 0
      m.user.msg("Cannot send a negative amount.")
      return
    end

    # Attempt the transaction (will raise on InsufficientFunds)
    begin
      db.create_transaction_from_tip(user_id, recipient_user_id, satoshi, message)
    rescue Bitbot::InsufficientFundsError
      m.reply "Insufficient funds! It's the thought that counts.", true
      return
    end

    # Success! Let the room know...
    m.reply "[✔] Verified: ".irc(:grey).irc(:bold) +
      m.user.user.irc(:bold) +
      " ➜ ".irc(:grey) +
      satoshi_with_usd(satoshi) +
      " ➜ ".irc(:grey) +
      recipient_ircuser.user.irc(:bold)

    # ... and let the sender know privately ...
    m.user.msg "You just sent " +
      recipient_ircuser.user.irc(:bold) + " " +
      satoshi_with_usd(satoshi) +
      " in " +
      m.channel.name.irc(:bold) +
      " bringing your balance to " +
      satoshi_with_usd(db.get_balance_for_user_id(user_id)) +
      "."

    # ... and let the recipient know privately.
    recipient_ircuser.msg m.user.user.irc(:bold) +
      " just sent you " +
      satoshi_with_usd(satoshi) +
      " in " +
      m.channel.name.irc(:bold) +
      " bringing your balance to " +
      satoshi_with_usd(db.get_balance_for_user_id(recipient_user_id)) +
      ". Type 'help' to list bitbot commands."
  end
end


