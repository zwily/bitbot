module StyledIrcString
  CODES = {
    :color     => "\x03",
    :bold      => "\x02",
    :underline => "\x1f",
    :inverse   => "\x16",
    :clear     => "\x0f",
  }

  COLORS = {
    0  => %w(white),
    1  => %w(black),
    2  => %w(blue navy),
    3  => %w(green),
    4  => %w(red),
    5  => %w(brown maroon),
    6  => %w(purple),
    7  => %w(orange olive),
    8  => %w(yellow),
    9  => %w(light_green lime),
    10 => %w(teal a_green blue_cyan),
    11 => %w(light_cyan cyan aqua),
    12 => %w(light_blue royal),
    13 => %w(pink light_purple fuchsia),
    14 => %w(grey),
    15 => %w(light_grey silver),
  }    

  def code_for_color(color)
    COLORS.each do |code, colors|
      if colors.include? color.to_s
        return "%02d" % code
      end
    end

    nil
  end

  def irc(attr1, attr2 = nil)
    if CODES[attr1]
      return "#{CODES[attr1]}#{self}#{CODES[:clear]}"
    elsif fg_color = code_for_color(attr1)
      bg_color = code_for_color(attr2)
      bg_string = bg_color ? ",#{bg_color}" : ""

      return "#{CODES[:color]}#{fg_color}#{bg_string}#{self}#{CODES[:clear]}"
    end

    self
  end
end

class String
  include StyledIrcString
end
