module Kaesen

  # Exchange markets.
  # @abstract
  class Market
    attr_reader :name
    
    def initialize
      @name = nil         # [String] name of exchange market
      @api_key    = nil   # [String]
      @api_secret = nil   # [String]
      @url_public  = nil  # [String]
      @url_private = nil  # [String]
    end

    #############################################################
    # API for public information
    #############################################################

    # Get ticker information.
    # @abstract
    # @return [hash] ticker
    #   ask: [BigDecimal] 最良売気配値
    #   bid: [BigDecimal] 最良買気配値
    #   last: [BigDecimal] 最近値(?用語要チェック), last price
    #   high: [BigDecimal] 高値
    #   low: [BigDecimal] 安値
    #   volume: [BigDecimal] 取引量
    #   ltimestamp: [int] Local Timestamp
    def ticker
      raise NotImplemented.new()
    end

    # Get order book.
    # @abstract
    # @return [hash] array of market depth
    #   asks: [Array] 売りオーダー
    #      price : [BigDecimal]
    #      size : [BigDecimal]
    #   bids: [Array] 買いオーダー
    #      price : [BigDecimal]
    #      size : [BigDecimal]
    #   ltimestamp: [int] Local Timestamp
    def depth
      raise NotImplemented.new()
    end

    #############################################################
    # API for private user data and trading
    #############################################################

    # Get account balance.
    # @abstract
    # @return [hash] account_balance_hash
    #   jpy: [hash]
    #      amount: [BigDecimal] 総日本円
    #      available: [BigDecimal] 取引可能な日本円
    #   btc [hash]
    #      amount: [BigDecimal] 総BTC
    #      available: [BigDecimal] 取引可能なBTC
    #   ltimestamp: [int] Local Timestamp
    def balance
      raise NotImplemented.new()
    end

    # Buy the amount of Bitcoin at the rate.
    # 指数注文 買い.
    # @abstract
    # @param [BigDecimal] rate
    # @param [BigDecimal] amount
    # @return [hash] history_order_hash
    #   success: [bool]
    #   id: [int] order id in the market
    #   rate: [BigDecimal]
    #   amount: [BigDecimal]
    #   order_type: [String] "sell" or "buy"
    #   ltimestamp: [int] Local Timestamp
    def buy(rate, amount=BigDecimal.new("0.0"))
      raise NotImplemented.new()
    end

    # Sell the amount of Bitcoin at the rate.
    # 指数注文 売り.
    # @abstract
    # @param [BigDecimal] rate
    # @param [BigDecimal] amount
    # @return [hash] history_order_hash
    #   success: [String] "true" or "false"
    #   id: [int] order id in the market
    #   rate: [BigDecimal]
    #   amount: [BigDecimal]
    #   order_type: [String] "sell" or "buy"
    #   ltimestamp: [int] Local Timestamp
    def sell(rate, amount=BigDecimal.new("0.0"))
      raise NotImplemented.new()
    end

    private

    # Check the API key and API secret key.
    def have_key?
      raise "Your #{@name} API key is not set"    if @api_key.nil?
      raise "Your #{@name} API secret is not set" if @api_secret.nil?
    end

    class ConnectionFailedException < StandardError; end
    class APIErrorException < StandardError; end
    class JSONException < StandardError; end
  end
end