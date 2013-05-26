module Bitbot::UpdateExchangeRates
  def on_update_exchange_rates(event = nil)
    self.exchange_rates = blockchain.get_exchange_rates()
  end
end
