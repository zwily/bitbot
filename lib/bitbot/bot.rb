# coding: utf-8

require 'cinch'
require 'bitbot/database'
require 'bitbot/blockchain'
require 'ircstring'

module Bitbot
  class Bot < Cinch::Bot
    def initialize(config = {})
      @bot_config = config
      @cached_addresses = nil
      @cached_exchange_rates = nil

      super() do
        configure do |c|
          c.server   = config['irc']['server']
          c.port     = config['irc']['port']
          c.ssl.use  = config['irc']['ssl']
          c.channels = config['irc']['channels']
          c.nick     = config['irc']['nick'] || 'bitbot'
          c.user     = config['irc']['username'] || 'bitbot'
          c.password = config['irc']['password']
          c.verbose  = config['irc']['verbose']
        end

        on :private, /^help$/ do |m|
          self.bot.command_help(m)
        end

        on :private, /^balance/ do |m|
          self.bot.command_balance(m)
        end

        on :private, /^history/ do |m|
          self.bot.command_history(m)
        end

        on :private, /^withdraw$/ do |m|
          m.reply "Usage: withdraw <amount in BTC> <address>"
        end

        on :private, /^withdraw\s+([\d.]+)\s+([13][0-9a-zA-Z]{26,35})/ do |m, amount, address|
          self.bot.command_withdraw(m, amount, address)
        end

        on :private, /^deposit/ do |m|
          self.bot.command_deposit(m)
        end

        on :channel, /^\+tipstats$/ do |m|
          self.bot.command_tipstats(m)
        end

        on :channel, /^\+tip\s+(\w+)\s+([\d.]+)\s+?(.*)/ do |m, recipient, amount, message|
          self.bot.command_tip(m, recipient, amount, message)
        end
      end
    end

    def get_db
      Bitbot::Database.new(File.join(@bot_config['data']['path'], "bitbot.db"))
    end

    def get_blockchain
      Bitbot::Blockchain.new(@bot_config['blockchain']['wallet_id'],
                             @bot_config['blockchain']['password1'],
                             @bot_config['blockchain']['password2'])
    end

    def satoshi_to_str(satoshi)
      str = "฿%.8f" % (satoshi.to_f / 10**8)
      # strip trailing 0s
      str.gsub(/0*$/, '')
    end

    def satoshi_to_usd(satoshi)
      if @cached_exchange_rates && @cached_exchange_rates["USD"]
        "$%.2f" % (satoshi.to_f / 10**8 * @cached_exchange_rates["USD"]["15m"])
      else
        "$?"
      end
    end

    def satoshi_with_usd(satoshi)
      btc_str = satoshi_to_str(satoshi)
      if satoshi < 0
        btc_str = btc_str.irc(:red)
      else
        btc_str = btc_str.irc(:green)
      end

      usd_str = "[".irc(:grey) + satoshi_to_usd(satoshi).irc(:blue) + "]".irc(:grey)

      "#{btc_str} #{usd_str}"
    end

    # This should be called periodically to keep exchange rates up to
    # date.
    def update_exchange_rates
      @cached_exchange_rates = get_blockchain().get_exchange_rates()
    end

    # This method needs to be called periodically, like every minute in
    # order to process new transactions.
    def update_addresses
      cache_file = File.join(@bot_config['data']['path'], "cached_addresses.yml")
      if @cached_addresses.nil?
        # Load from the cache, if available, on first load
        @cached_addresses = YAML.load(File.read(cache_file)) rescue nil
      end

      blockchain = get_blockchain()

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
          self.process_new_transactions_for_address(address, user_id, all_addresses)
        end
      end

      # Thread-safe? Sure, why not.
      @cached_addresses = new_addresses

      # Cache them on disk for faster startups
      File.write(cache_file, YAML.dump(@cached_addresses))
    end

    def process_new_transactions_for_address(address, user_id, all_addresses)
      db = get_db()
      blockchain = get_blockchain()

      existing_transactions = {}
      db.get_incoming_transaction_ids().each do |txid|
        existing_transactions[txid] = true
      end

      response = blockchain.get_details_for_address(address["address"])

      username = db.get_username_for_user_id(user_id)
      ircuser = self.user_with_username(username)

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
          ircuser.msg "Waiting for confirmation of transaction of " +
            satoshi_with_usd(amount) +
            " in transaction #{tx["hash"].irc(:grey)}"
          next
        end

        # There is a unique constraint on incoming_transaction, so this
        # will fail if for some reason we try to add it again.
        if db.create_transaction_from_deposit(user_id, amount, tx["hash"])
          # Notify the depositor
          if ircuser
            ircuser.msg "Received deposit of " +
              satoshi_with_usd(amount) + ". Current balance is " +
              satoshi_with_usd(db.get_balance_for_user_id(user_id)) + "."
          end
        end
      end
    end

    def user_with_username(username)
      self.bot.user_list.each do |user|
        return user if user.user == username
      end
    end

    def command_help(msg)
      msg.reply "Commands: balance, history, withdraw, deposit, +tip, +tipstats"
    end

    def command_balance(msg)
      db = get_db()
      user_id = db.get_or_create_user_id_for_username(msg.user.user)

      msg.reply "Balance is #{satoshi_with_usd(db.get_balance_for_user_id(user_id))}"
    end

    def command_deposit(msg, create = true)
      db = get_db()
      user_id = db.get_or_create_user_id_for_username(msg.user.user)

      unless @cached_addresses
        msg.reply "Bitbot is not initialized yet. Please try again later."
        return
      end

      if address = @cached_addresses[user_id]
        msg.reply "Send deposits to #{address["address"].irc(:bold)}. " +
          "This address is specific to you, and any funds delivered " +
          "to it will be added to your account after confirmation."
        return
      end

      unless create
        msg.reply "There was a problem getting your deposit address. " +
          "Please contact your friends Bitbot admin."
        return
      end

      # Attempt to create an address.
      blockchain = get_blockchain()
      blockchain.create_deposit_address_for_user_id(user_id)

      # Force a refresh of the cached address list...
      self.update_addresses()

      self.command_deposit(msg, false)
    end

    def command_history(msg)
      db = get_db()
      user_id = db.get_or_create_user_id_for_username(msg.user.user)

      command_balance(msg)

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

        msg.reply "#{time.irc(:grey)}: #{amount} #{action} #{"(#{tx[:note]})".irc(:grey) if tx[:note]}"

        n += 1
        break if n >= 10
      end
    end

    def command_withdraw(msg, amount, address)
      db = get_db()
      user_id = db.get_or_create_user_id_for_username(msg.user.user)

      satoshi = (amount.to_f * 10**8).to_i

      # Perform the local transaction in the database. Note that we
      # don't do the blockchain update in the transaction, because we
      # don't want to roll back the transaction if the blockchain update
      # *appears* to fail. It might look like it failed, but really
      # succeed, letting someone withdraw money twice.
      # TODO: don't hardcode fee
      begin
        db.create_transaction_from_withdrawal(user_id, satoshi, 500000, address)
      rescue InsufficientFundsError
        msg.reply "You don't have enough to withdraw #{satoshi_to_str(satoshi)} + 0.0005 fee"
        return
      end

      blockchain = get_blockchain()
      response = blockchain.create_payment(address, satoshi, 500000)
      if response["tx_hash"]
        msg.reply "Sent #{satoshi_with_usd(satoshi)} to #{address.irc(:bold)} " +
          "in transaction #{response["tx_hash"].irc(:grey)}."
      else
        msg.reply "Something may have gone wrong with your withdrawal. Please contact " +
          "your friendly Bitbot administrator to investigate where your money is."
      end
    end

    def command_tipstats(msg)
      db = get_db()
      stats = db.get_tipping_stats

      str = "Stats: ".irc(:grey) +
        "tips today: " +
        satoshi_with_usd(0 - stats[:total_tipped]) + " " +
        "#{stats[:total_tips]} tips "

      if stats[:tippers].length > 0
        str += "biggest tipper: ".irc(:black) +
          stats[:tippers][0][0].irc(:bold) +
          " (#{satoshi_with_usd(0 - stats[:tippers][0][1])}) "
      end

      if stats[:tippees].length > 0
        str += "biggest recipient: ".irc(:black) +
          stats[:tippees][0][0].irc(:bold) +
          " (#{satoshi_with_usd(stats[:tippees][0][1])}) "
      end

      msg.reply str
    end

    def command_tip(msg, recipient, amount, message)
      db = get_db()

      # Look up sender
      user_id = db.get_or_create_user_id_for_username(msg.user.user)

      # Look up recipient
      recipient_ircuser = msg.channel.users.keys.find {|u| u.name == recipient }
      unless recipient_ircuser
        msg.user.msg("Could not find #{recipient} in the channel list.")
        return
      end
      recipient_user_id = db.get_or_create_user_id_for_username(recipient_ircuser.user)

      # Convert amount to satoshi
      satoshi = (amount.to_f * 10**8).to_i
      if satoshi <= 0
        msg.user.msg("Cannot send a negative amount.")
        return
      end

      # Attempt the transaction (will raise on InsufficientFunds)
      begin
        db.create_transaction_from_tip(user_id, recipient_user_id, satoshi, message)
      rescue InsufficientFundsError
        msg.reply "Insufficient funds! It's the thought that counts.", true
        return
      end

      # Success! Let the room know...
      msg.reply "[✔] Verified: ".irc(:grey).irc(:bold) +
        msg.user.user.irc(:bold) +
        " ➜ ".irc(:grey) +
        satoshi_with_usd(satoshi) +
        " ➜ ".irc(:grey) +
        recipient_ircuser.user.irc(:bold)

      # ... and let the sender know privately ...
      msg.user.msg "You just sent " +
        recipient_ircuser.user.irc(:bold) + " " +
        satoshi_with_usd(satoshi) +
        " in " +
        msg.channel.name.irc(:bold) +
        " bringing your balance to " +
        satoshi_with_usd(db.get_balance_for_user_id(user_id)) +
        "."

      # ... and let the recipient know privately.
      recipient_ircuser.msg msg.user.user.irc(:bold) +
        " just sent you " +
        satoshi_with_usd(satoshi) +
        " in " +
        msg.channel.name.irc(:bold) +
        " bringing your balance to " +
        satoshi_with_usd(db.get_balance_for_user_id(recipient_user_id)) +
        ". Type 'help' to list bitbot commands."
    end
  end
end
