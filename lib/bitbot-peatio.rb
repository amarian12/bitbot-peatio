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
      map  = {created_at: :timestamp, remaining_volume: :amount, volume: nil, executed_volume: nil, side: nil, avg_price: nil, market: nil, state: nil}
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

    def buy(options)
      resp = client.post '/api/v2/orders', market: market, side: 'buy', volume: options[:amount], price: options[:price]
      check_response(resp)
      build_order(resp)
    end

    def sell(options)
      resp = client.post '/api/v2/orders', market: market, side: 'sell', volume: options[:amount], price: options[:price]
      check_response(resp)
      build_order(resp)
    end

    def cancel(order_id)
      resp = client.post '/api/v2/order/delete', id: order_id
      check_response(resp)
      build_order(resp)
    end

    def sync(order)
      order_id = order.is_a?(BitBot::Order) ? order.order_id : order.to_i
      resp = client.get '/api/v2/order', id: order_id
      check_response(resp)
      build_order resp
    end

    def orders
      resp = client.get '/api/v2/orders', market: market
      check_response(resp)

      resp.collect do |hash|
        build_order(hash)
      end
    end

    def account
      resp = client.get '/api/v2/members/me'
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
      return unless response.is_a?(Hash) && response.has_key?('error')

      code = response['error']['code']
      msg  = response['error']['message']
      case code
      when 2001 then raise UnauthorizedError, msg
      when 2003 then raise CanceledError, msg
      else raise Error, msg
      end
    end

    def build_order(hash)
      map = { id: :order_id,
              volume: :amount,
              remaining_volume: :remaining,
              executed_volume: nil,
              state: nil,
              market: nil,
              trades: nil,
              created_at: :timestamp }
      order = Order.new rekey(hash, map).merge(original: hash, agent: self)
      order.type   = 'exchange limit'
      order.status = case hash['state']
                     when 'wait' then 'open'
                     when 'cancel' then 'cancelled'
                     else 'closed'
                     end
      order
    end

    def build_account(member)
      accounts = member.delete 'accounts'
      account = Account.new original: member, agent: self
      account.balances = accounts.map {|acct| build_balance(acct) }
      account
    end

    def build_balance(acct)
      Balance.new(currency: acct['currency'], amount: acct['balance'], locked: acct['locked'], agent: self, original: acct)
    end

  end
end

BitBot.define :peatio, BitBot::Peatio
