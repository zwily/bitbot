# coding: utf-8

require 'ircstring'
require 'bitbot/database'
require 'bitbot/blockchain'

module Bitbot::Common
  def cached_addresses
    @cached_addresses
  end

  def cached_addresses=(new)
    @cached_addresses = new
  end

  def exchange_rate(currency)
    if @cached_exchange_rates
      return @cached_exchange_rates[currency]["15m"]
    end
    nil
  end

  def exchange_rates=(new)
    @cached_exchange_rates = new
  end

  def withdrawal_fee
    config['blockchain']['withdrawal_fee'] || 50000
  end

  #
  # Returns a database handle for use in the current thread.
  #
  def db
    Thread.current[:bitbot_db] ||=
      Bitbot::Database.new(File.join(config['data']['path'], "bitbot.db"))
  end

  #
  # Returns a Blockchain API helper. Everyone uses the same one,
  # but it doesn't keep any state so it's fine.
  #
  def blockchain
    @@cached_blockchain ||=
      Bitbot::Blockchain.new(config['blockchain']['wallet_id'],
                             config['blockchain']['password1'],
                             config['blockchain']['password2'])
  end

  #
  # Returns the User for the given username. If you want to get
  # a User based on nick, User(nick) is easier.
  #
  def user_with_username(username)
    bot.user_list.each do |user|
      return user if user.user == username
    end
    nil
  end

  #
  # Takes a string, and returns an int with number of satoshi.
  # Eventually this could be smart enough to handle specified units too,
  # rather than just assuming BTC every time.
  #
  def str_to_satoshi(str)
    val = str.to_f
    val = val / 10**3 if str.to_s.end_with?('m')
    (val * 10**8).to_i
  end

  #
  # Some number formatting helpers
  #
  def satoshi_to_str(satoshi)
    str = "฿%.8f" % (satoshi.to_f / 10**8)
    # strip trailing 0s
    str.gsub(/0*$/, '')
  end

  def satoshi_to_usd(satoshi)
    rate = exchange_rate("USD")
    if rate
      "$%.2f" % (satoshi.to_f / 10**8 * rate)
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
end

