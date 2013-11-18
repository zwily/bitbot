require 'cinch'
require 'ircstring'

require 'bitbot/database'
require 'bitbot/plugin/common'
require 'bitbot/plugin/help'
require 'bitbot/plugin/balance'
require 'bitbot/plugin/deposit'
require 'bitbot/plugin/history'
require 'bitbot/plugin/tip'
require 'bitbot/plugin/tipstats'
require 'bitbot/plugin/withdraw'
require 'bitbot/plugin/update_addresses'
require 'bitbot/plugin/update_exchange_rates'

class Bitbot::Plugin
  include Cinch::Plugin

  include Bitbot::Common
  include Bitbot::Help
  include Bitbot::Balance
  include Bitbot::Deposit
  include Bitbot::History
  include Bitbot::Tip
  include Bitbot::TipStats
  include Bitbot::Withdraw
  include Bitbot::UpdateAddresses
  include Bitbot::UpdateExchangeRates

  def initialize(bot)
    super
    Bitbot::Database.new(File.join(config['data']['path'], "bitbot.db")).upgrade_schema()
  end

  set :prefix, ""

  #
  # Private messages
  #
  match /^help(.*)$/, :method => :on_help, :react_on => :private
  match /^balance$/, :method => :on_balance, :react_on => :private
  match /^history$/, :method => :on_history, :react_on => :private
  match /^withdraw(.*)$/, :method => :on_withdraw, :react_on => :private
  match /^deposit$/, :method => :on_deposit, :react_on => :private

  #
  # Channel messages
  #
  match /^\+tipstats$/, :method => :on_tipstats, :react_on => :channel
  match /^\+tip\s+(\w+)\s+([\d.]+m?)\s+?(.*)/, :method => :on_tip, :react_on => :channel

  #
  # Timer jobs
  #
  timer 60, :method => :on_update_exchange_rates
  timer 60, :method => :on_update_addresses

  #
  # Also run the timer jobs on connect
  #
  listen_to :connect, :method => :on_update_exchange_rates
  listen_to :connect, :method => :on_update_addresses
end
