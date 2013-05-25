require 'httparty'
require 'cgi'
require 'json'

module Bitbot
  class Blockchain
    def initialize(id, password1, password2)
      @id = id
      @password1 = password1
      @password2 = password2
    end

    def request(api, action = nil, params = {})
      path = if api == :merchant
               "merchant/#{@id}/#{action}"
             elsif api == :ticker
               "ticker"
             else
               "#{api}/#{action}"
             end
      url = "https://blockchain.info/#{path}?"
      params.each do |key, value|
        url += "#{key}=#{CGI::escape value.to_s}&"
      end

      response = HTTParty.get(url)
      raise "HTTP Error: #{response}" unless response.code == 200

      JSON.parse(response.body)
    end

    def create_deposit_address_for_user_id(user_id)
      self.request(:merchant, :new_address,
                   :password => @password1,
                   :second_password => @password2,
                   :label => user_id)
    end

    def get_details_for_address(address)
      self.request(:address, address, :format => :json)
    end

    def get_addresses_in_wallet
      response = self.request(:merchant, :list, :password => @password1)
      response["addresses"]
    end

    def get_balance_for_address(address, confirmations = 1)
      response = self.request(:merchant, :address_balance,
                              :password => @password1,
                              :address => address,
                              :confirmations => confirmations)
      response["balance"]
    end

    def create_payment(address, amount, fee)
      response = self.request(:merchant, :payment,
                              :password => @password1,
                              :second_password => @password2,
                              :to => address,
                              :amount => amount,
                              :fee => fee)
      response
    end

    def get_exchange_rates
      self.request(:ticker)
    end
  end
end
