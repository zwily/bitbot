# coding: utf-8

module Bitbot::TipStats
  def on_tipstats(m)
    stats = db.get_tipping_stats

    str = "Stats: ".irc(:grey) +
      "tips today: " +
      satoshi_with_usd(0 - stats[:total_tipped]) + " " +
      "(#{stats[:total_tips]} tips) "

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

    m.reply str
  end
end



