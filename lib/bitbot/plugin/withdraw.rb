module Bitbot::Withdraw
  def on_withdraw(m, args)
    if args =~ /\s+([\d.]+)\s+([13][0-9a-zA-Z]{26,35})/
      satoshi = str_to_satoshi($1)
      address = $2

      user_id = db.get_or_create_user_id_for_username(m.user.user)

      # Perform the local transaction in the database. Note that we
      # don't do the blockchain update in the transaction, because we
      # don't want to roll back the transaction if the blockchain update
      # *appears* to fail. It might look like it failed, but really
      # succeed, letting someone withdraw money twice.
      begin
        db.create_transaction_from_withdrawal(user_id, satoshi, withdrawal_fee, address)
      rescue Bitbot::InsufficientFundsError
        m.reply "You don't have enough to withdraw #{satoshi_to_str(satoshi)} + 0.0005 fee"
        return
      end

      response = blockchain.create_payment(address, satoshi, withdrawal_fee)
      if response["tx_hash"]
        m.reply "Sent #{satoshi_with_usd(satoshi)} to #{address.irc(:bold)} " +
          "in transaction #{response["tx_hash"].irc(:grey)}."
      else
        m.reply "Something may have gone wrong with your withdrawal. Please contact " +
          "your friendly Bitbot administrator to investigate where your money is."
      end
    else
      m.reply "Usage: withdraw <amount in BTC> <address>"
      m.reply "#{satoshi_to_str(withdrawal_fee)} BTC will also be withdrawn for the transaction fee."
    end
  end
end

