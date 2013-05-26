module Bitbot::UpdateAddresses
  def cache_file_path
    File.join(config['data']['path'], "cached_addresses.yml")
  end

  def on_update_addresses(event = nil)
    if cached_addresses.nil?
      # Load from the cache, if available, on first load
      self.cached_addresses = YAML.load(File.read(cache_file_path)) rescue nil
    end

    # Updates the cached map of depositing addresses. 
    new_addresses = {}
    all_addresses = []

    addresses = blockchain.get_addresses_in_wallet()
    addresses.each do |address|
      all_addresses << address["address"]
      next unless address["label"] =~ /^\d+$/

      user_id = address["label"].to_i

      new_addresses[user_id] = address

      # We set a flag on the address saying we need to get the
      # confirmed balance IF the previous entry has the flag, OR
      # the address is new OR if the balance does not equal the
      # previous balance. We only clear the field when the balance
      # equals the confirmed balance.
      address["need_confirmed_balance"] = @cached_addresses[user_id]["need_confirmed_balance"] rescue true
      if address["balance"] != (@cached_addresses[user_id]["balance"] rescue nil)
        address["need_confirmed_balance"] = true
      end
    end

    # Now go through new addresses, performing any confirmation checks
    # for flagged ones.
    new_addresses.each do |user_id, address|
      if address["need_confirmed_balance"]
        balance = blockchain.get_balance_for_address(address["address"])
        address["confirmed_balance"] = balance

        if address["confirmed_balance"] == address["balance"]
          address["need_confirmed_balance"] = false
        end

        # Process any transactions for this address
        process_new_transactions_for_address(address, user_id, all_addresses)
      end
    end

    # Thread-safe? Sure, why not.
    self.cached_addresses = new_addresses

    # Cache them on disk for faster startups
    File.write(cache_file_path, YAML.dump(new_addresses))
  end

  def process_new_transactions_for_address(address, user_id, all_addresses)
    existing_transactions = {}
    db.get_incoming_transaction_ids.each do |txid|
      existing_transactions[txid] = true
    end

    response = blockchain.get_details_for_address(address["address"])

    username = db.get_username_for_user_id(user_id)

    response["txs"].each do |tx|
      # Skip ones we already have in the database
      next if existing_transactions[tx["hash"]]

      # Skip any transactions that have an existing bitbot address
      # as an input
      if tx["inputs"].any? {|input| all_addresses.include? input["prev_out"]["addr"] }
        debug "Skipping tx with bitbot input address: #{tx["hash"]}"
        next
      end

      # find the total amount for this address
      amount = 0
      tx["out"].each do |out|
        if out["addr"] == address["address"]
          amount += out["value"]
        end
      end

      # Skip unless it's in a block (>=1 confirmation)
      if !tx["block_height"] || tx["block_height"] == 0
        # TODO: only tell them this one time.
        if ircuser = user_with_username(username)
          ircuser.msg "Waiting for confirmation of transaction of " +
            satoshi_with_usd(amount) +
            " in transaction #{tx["hash"].irc(:grey)}"
        end
        next
      end

      # There is a unique constraint on incoming_transaction, so this
      # will fail if for some reason we try to add it again.
      if db.create_transaction_from_deposit(user_id, amount, tx["hash"])
        # Notify the depositor, if they're around
        if ircuser = user_with_username(username)
          ircuser.msg "Received deposit of " +
            satoshi_with_usd(amount) + ". Current balance is " +
            satoshi_with_usd(db.get_balance_for_user_id(user_id)) + "."
        end
      end
    end
  end
end

