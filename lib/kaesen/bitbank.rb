require_relative 'market.rb'
require 'net/http'
require 'openssl'
require 'json'
require 'bigdecimal'
require 'ruby_bitbankcc'

module Kaesen
  # Bitbank Wrapper Class
  # https://docs.bitbank.cc/

  class Bitbank < Market
    @@nonce = 0

    def initialize(options = {})
      super()
      @name        = "Bitbank"
      @api_key     = ENV["BITBANK_KEY"]
      @api_secret  = ENV["BITBANK_SECRET"]
      @url_public  = "https://public.bitbank.cc"
      @url_private = "https://api.bitbank.cc/v1"
      
      @bbcc = Bitbankcc.new(@api_key, @api_secret)

      options.each do |key, value|
        instance_variable_set("@#{key}", value)
      end
      yield(self) if block_given?
    end

    #############################################################
    # API for public information
    #############################################################
    
    def balance
      h = @bbcc.read_balance
      h = JSON.parse(h)
      assets = h["data"]["assets"]
      asset_datas = {}
      assets.each do |a|
        if !a["asset"].empty?
          # p a["asset"]
          currency = a["asset"]
          asset_datas[currency] = {}
          BigDecimal.new(h["ask"].to_s)
          asset_datas[currency]["amount"] = BigDecimal.new(a["onhand_amount"].to_s)
          asset_datas[currency]["available"] = BigDecimal.new(a["free_amount"].to_s)
        end
      end
      asset_datas
    end

    # Get ticker information.
    # @param [string] pair
    # @return [hash] ticker
    #   ask: [BigDecimal] 最良売気配値
    #   bid: [BigDecimal] 最良買気配値
    #   last: [BigDecimal] 最近値(?用語要チェック), last price
    #   high: [BigDecimal] 高値
    #   low: [BigDecimal] 安値
    #   volume: [BigDecimal] 取引量
    #   timestamp: [int] タイムスタンプ
    #   ltimestamp: [int] ローカルタイムスタンプ
    def ticker(pair)
      h = get_ssl(@url_public + "/" + pair + "/ticker")
      h = h["data"]
      {
        "ask"        => BigDecimal.new(h["sell"]),
        "bid"        => BigDecimal.new(h["buy"]),
        "last"       => BigDecimal.new(h["last"]),
        "high"       => BigDecimal.new(h["high"]), # of the previous 24 hours
        "low"        => BigDecimal.new(h["low"]), # of the previous 24 hours
        "volume"     => BigDecimal.new(h["vol"]), # of the previous 24 hours
        "ltimestamp" => Time.now.to_i,
        "timestamp"  => h["timestamp"],
      }
    end

    # Get order book.
    # @abstract
    # @param [String] pair
    # @return [hash] array of market depth
    #   asks: [Array] 売りオーダー
    #      price : [BigDecimal]
    #      size : [BigDecimal]
    #   bids: [Array] 買いオーダー
    #      price : [BigDecimal]
    #      size : [BigDecimal]
    #   ltimestamp: [int] ローカルタイムスタンプ
    def depth(pair)
      h = get_ssl(@url_public + "/" + pair + "/depth")
      h = h["data"]
      {
        "asks"       => h["asks"].map{|a,b| [BigDecimal.new(a.to_s), BigDecimal.new(b.to_s)]}, # to_s でないと誤差が生じる
        "bids"       => h["bids"].map{|a,b| [BigDecimal.new(a.to_s), BigDecimal.new(b.to_s)]}, # to_s でないと誤差が生じる
        "ltimestamp" => Time.now.to_i,
      }
    end
    
    # buy
    # @param
    def buy(pair, rate, amount=BigDecimal.new(0))
      have_key?
      address = @url_private + "/user/spot/order"
      body = {
        "pair"        => pair,
        "amount"      => amount.to_f.round(4),
        "side"        => "buy",
        "type"        => "limit",
        "price"         => rate,
      }
      h = post_ssl(address, body)
      result = h["success"].to_i == 1 ? "true" : "false"
      if result == "true"
        {
          "success"    => result,
          "id"         => h["data"]["order_id"].to_s,
          "rate"       => BigDecimal.new(rate.to_s),
          "amount"     => BigDecimal.new(amount.to_s),
          "order_type" => "buy",
          "ltimestamp" => Time.now.to_i,
        }
      else
        {
          "success"    => result,
          "error"      => h["data"]["code"]
        }
      end
    end
    
    # sell
    # @param
    def sell(pair, rate, amount=BigDecimal.new(0))
      have_key?
      address = @url_private + "/user/spot/order"
      body = {
        "pair"        => pair,
        "amount"      => amount.to_f.round(4),
        "side"        => "sell",
        "type"        => "limit",
        "price"         => rate,
      }
      h = post_ssl(address, body)
      result = h["success"].to_i == 1 ? "true" : "false"
      if result == "true"
        {
          "success"    => result,
          "id"         => h["data"]["order_id"].to_s,
          "rate"       => BigDecimal.new(rate.to_s),
          "amount"     => BigDecimal.new(amount.to_s),
          "order_type" => "sell",
          "ltimestamp" => Time.now.to_i,
        }
      else
        {
          "success"    => result,
          "error"      => h["data"]["code"]
        }
      end
    end
    
    # 現在の注文情報取得
    def opens
      h = @bbcc.read_active_orders('eth_btc')
      h = JSON.parse(h)
      success = h["success"] == 1 ? "true" : "false"
      if !h["data"]["orders"].empty?
        h["data"]["orders"].map do |order|
          order_type = order["side"] # when value["action"] is "bid"
          {
            "success"    => success,
            "id"         => order["order_id"],
            "pair"       => order["pair"],
            "rate"       => BigDecimal.new(order["price"].to_s),
            "amount"     => BigDecimal.new(order["start_amount"].to_s),
            "order_type" => order["type"],
          }
        end
      else
        {
          "success"     => success,
        }
      end
    end

    private

    def initialize_https(uri)
      https = Net::HTTP.new(uri.host, uri.port)
      https.use_ssl = true
      https.open_timeout = 5
      https.read_timeout = 15
      https.verify_mode = OpenSSL::SSL::VERIFY_PEER
      https.verify_depth = 5
      https
    end

    # Connect to address via https, and return json response.
    def get_ssl(address)
      uri = URI.parse(address)

      begin
        request = Net::HTTP::Get.new(uri, initheader = headers)
        https = initialize_https(uri)
        https.start {|w|
          response = w.get(uri.request_uri)
          case response
            when Net::HTTPSuccess
              json = JSON.parse(response.body)
              raise JSONException, response.body if json == nil
              return json
            else
              raise ConnectionFailedException, "Failed to connect to #{@name}."
          end
        }
      rescue
        raise
      end
    end
    
    # Connect to address via https, and return json response.
    def get_ssl2(path)
      uri = URI.parse(@url_private + path)
      
      nonce = get_nonce
      secret = @api_secret
      text = nonce.to_s + "/v1" + path + "" # ACCESS-NONCE、リクエストのパス、クエリパラメータ」 を連結させたもの
      signature = OpenSSL::HMAC::hexdigest(OpenSSL::Digest.new('sha512'), secret, text)
      
      # headers = {
      #   "ACCESS-KEY" => @api_key,
      #   "ACCESS-NONCE" => get_nonce.to_s,
      #   "ACCESS-SIGNATURE" => signature,
      # }

      begin
        req = Net::HTTP::Get.new(uri.path)
        req["ACCESS-KEY"] = @api_key
        req["ACCESS-NONCE"] = nonce
        req["ACCESS-SIGNATURE"] = signature
        https = initialize_https(uri)
        https.start { |w|
          res = w.request(req)
          p res.body
        }
        exit
        # https.start {|w|
        #   p uri.request_uri
        #   response = w.get(uri.request_uri)
        #   # debug
        #   p response
        #   exit
        #   response = w.get(uri.request_uri)
        #   case response
        #     when Net::HTTPSuccess
        #       json = JSON.parse(response.body)
        #       raise JSONException, response.body if json == nil
        #       return json
        #     else
        #       raise ConnectionFailedException, "Failed to connect to #{@name}."
        #   end
        # }
      rescue
        raise
      end
    end

    def get_nonce
      pre_nonce = @@nonce
      next_nonce = (Time.now.to_i) * 100

      if next_nonce <= pre_nonce
        @@nonce = pre_nonce + 1
      else
        @@nonce = next_nonce
      end

      return @@nonce
    end

    def get_sign(req)
      secret = @api_secret
      # text = req.body
      text = ""

      OpenSSL::HMAC::hexdigest(OpenSSL::Digest.new('sha512'), secret, text)
    end

    # Connect to address via https, and return json response.
    def post_ssl(address, data={})
      uri = URI.parse(address)
      data["nonce"] = get_nonce

      begin
        req = Net::HTTP::Post.new(uri)
        req.set_form_data(data)
        req["Key"] = @api_key
        req["Sign"] = get_sign(req)

        https = initialize_https(uri)
        https.start {|w|
          response = w.request(req)
          case response
            when Net::HTTPSuccess
              json = JSON.parse(response.body)
              raise JSONException, response.body if json == nil
              return json
            else
              raise ConnectionFailedException, "Failed to connect to #{@name}: " + response.value
          end
        }
      rescue
        raise
      end
    end
    
    def http_request(uri, request)
      https = Net::HTTP.new(uri.host, uri.port)
      
      if @@ssl
        https.use_ssl = true
        https.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end
      
      response = https.start do |h|
        h.request(request)
      end
      response.body
    end
    
    def request_for_get(path, query = {})
      nonce = get_nonce
      uri = URI.parse @url_private + path
      signature = get_get_signature(path, @api_secret, nonce, query)
      # signature = get_sign(query)

      headers = {
        "Content-Type" => "application/json",
        "ACCESS-KEY" => @key,
        "ACCESS-NONCE" => nonce,
        "ACCESS-SIGNATURE" => signature
      }

      uri.query = query.empty? ? "" : query.to_query
      request = Net::HTTP::Get.new(uri.request_uri, initheader = headers)
      http_request(uri, request)
    end
    
    def get_get_signature(path, secret_key, nonce, query = {})
      query_string = !query.empty? ? '?' + query.to_query : ''
      message = nonce.to_s + path + query_string
      signature = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha256"), secret_key, message)
    end

  end
end
