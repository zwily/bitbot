module Bitbot::Help
  def on_help(m, args)
    m.reply "Commands: balance, history, withdraw, deposit, +tip, +tipstats"
  end
end
