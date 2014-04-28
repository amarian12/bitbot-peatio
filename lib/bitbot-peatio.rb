require 'bitbot'
require 'peatio_client'

module BitBot
  module Peatio

    def ticker
      map  = {sell: :ask, buy: :bid}
      resp = client.get("/api/v2/tickers/#{market}")
      check_response(resp)

      original = resp['ticker']
      Ticker.new rekey(original, map).merge(original: original, agent: self)
    end

    def offers
      map  = {created_at: :timestamp, volume: :amount}
      resp = client.get("/api/v2/order_book", market: market, asks_limit: 10, bids_limit: 10)
      check_response(resp)

      asks = resp['asks'].collect do |offer|
        Offer.new rekey(offer, map).merge(original: offer, agent: self)
      end
      bids = resp['bids'].collect do |offer|
        Offer.new rekey(offer, map).merge(original: offer, agent: self)
      end

      {asks: asks, bids: bids}
    end

    def asks
      offers[:asks]
    end

    def bids
      offers[:bids]
    end


    ### PRIVATE ###
    def buy(options)
      raise UnauthorizedError unless client.have_key?
      amount = options[:amount]
      price = options[:price]
      order_type = options[:type] || 'exchange limit'
      resp = client.order amount, price, order_type
      check_response(resp)

      build_order(resp)
    end

    def sell(options)
      raise UnauthorizedError unless client.have_key?
      amount = options[:amount]
      price = options[:price]
      order_type = options[:type] || 'exchange limit'
      resp = client.order (-amount), price, order_type
      check_response(resp)

      build_order(resp)
    end

    def cancel(order_id)
      raise UnauthorizedError unless client.have_key?
      resp = client.cancel(order_id)
      check_response(resp)

      order = build_order resp
      order.status == 'cancelled'
    end

    def sync(order)
      raise UnauthorizedError unless client.have_key?
      order_id = order.is_a?(BitBot::Order) ? order.order_id : order.to_i
      resp = client.status order_id
      check_response(resp)

      #TODO: bitfinex API return wrong side when order is executed, should re-check here!
      build_order resp
    end

    def orders
      raise UnauthorizedError unless client.have_key?
      resp = client.orders
      check_response(resp)

      resp.collect do |hash|
        build_order(hash)
      end
    end

    def account
      raise UnauthorizedError unless client.have_key?
      resp = client.balances
      check_response(resp)

      build_account(resp)
    end

    ### HELPER METHODS ###
    def currency
      'USD'
    end

    def rate
      Settings.rate
    end

    def client
      @client ||= PeatioAPI::Client.new(
        access_key: @key,
        secret_key: @secret,
        endpoint:   @options[:endpoint]
      )
    end

    def market
      @market ||= @options[:market] || 'btccny'
    end

    private

    def check_response(response)
      return unless response.has_key?('error')

      code = response['error']['code']
      msg  = response['error']['message']
      case code
      when 2001 then raise UnauthorizedError, msg
      when 2003 then raise CanceledError, msg
      else raise Error, msg
      end
    end

    def build_order(hash)
      map = { symbol: nil,
              id: :order_id,
              exchange: nil,
              avg_execution_price: :avg_price,
              is_live: nil,
              is_cancelled: nil,
              was_forced: nil,
              original_amount: :amount,
              remaining_amount: :remaining,
              executed_amount: nil
      }
      order = Order.new rekey(hash, map).merge(original: hash, agent: self)
      order.status = if hash['is_live']
                       'open'
                     elsif hash['is_cancelled']
                       'cancelled'
                     else
                       'closed'
                     end
      order
    end

    def build_account(arr)
      account = Account.new agent: self

      btc_balance = arr.detect{|bln| bln['currency'] == 'btc' && bln['type'] == 'exchange' }
      usd_balance = arr.detect{|bln| bln['currency'] == 'usd' && bln['type'] == 'exchange' }

      account.balances << Balance.new(currency: 'BTC', amount: btc_balance['amount'], agent: self)
      account.balances << Balance.new(currency: 'USD', amount: usd_balance['amount'], agent: self)
      account
    end
  end
end

BitBot.define :peatio, BitBot::Peatio
