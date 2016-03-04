require 'tushare/util' 

module Tushare 

  module Stock 

    include Tushare::Util 

    ## 
    #      获取个股历史交易记录
    #  Parameters
    #  ------
    #    code:string
    #                股票代码 e.g. 600848
    #    start_date:string
    #                开始日期 format：YYYY-MM-DD 为空时取到API所提供的最早日期数据
    #    end_date:string
    #                结束日期 format：YYYY-MM-DD 为空时取到最近一个交易日数据
    #    ktype：string
    #                数据类型，D=日k线 W=周 M=月 5=5分钟 15=15分钟 30=30分钟 60=60分钟，默认为D
    #  return
    #  -------
    #    DataFrame
    #        属性:日期 ，开盘价， 最高价， 收盘价， 最低价， 成交量， 价格变动 ，涨跌幅，5日均价，10日均价，20日均价，5日均量，10日均量，20日均量，换手率
    def get_hist_data(code, options = {})
      
      symbol_code = _code_to_symbol(code)

      raise 'invalid code' if symbol_code == ""

      options = { start_date: "", end_date: "", ktype: 'D', ascending: false }.merge(options)

      if K_LABELS.include?(options[:ktype].upcase)
        url = sprintf(DAY_PRICE_URL, P_TYPE["http"], DOMAINS["ifeng"], K_TYPE[options[:ktype].upcase], symbol_code)
      elsif K_MIN_LABELS.include?(options[:ktype])
        url = sprintf(DAY_PRICE_MIN_URL, P_TYPE["http"], DOMAINS["ifeng"], symbol_code, options[:ktype])
      else 
        raise 'ktype input error.'
      end 

      if INDEX_LABELS.include?(code) #& (K_LABELS.include?(ktype.upcase) || K_MIN_LABELS.include?(ktype))
        cols = INX_DAY_PRICE_COLUMNS 
      else 
        cols = DAY_PRICE_COLUMNS
      end

      resp = HTTParty.get(url)
      if resp.code.to_s == "200"
        records = JSON.parse(resp.body)["record"]
        if records.size > 0
          cols = INX_DAY_PRICE_COLUMNS if records.first.size == 14

          records.reverse! if options[:ascending] == false 
          if options[:start_date] != '' and options[:end_date] != ''
            records = records.select{|x| Time.parse(x[0]) <= Time.parse("#{options[:end_date]} 23:59") and Time.parse(x[0]) >= Time.parse("#{options[:start_date]} 00:00")}
          end

          records.map{|r| Hash[cols.zip(r)]}
        end
      else 
        []
      end
    end 
    #  """
    #      获取分笔数据
    #  Parameters
    #  ------
    #      code:string
    #                股票代码 e.g. 600848
    #      date:string
    #                日期 format：YYYY-MM-DD
    #   return
    #   -------
    #      DataFrame 当日所有股票交易数据(DataFrame)
    #            属性:成交时间、成交价格、价格变动，成交手、成交金额(元)，买卖类型
    #  """
    def get_tick_data(code, date = '')
      return nil if code.nil? or code.size != 6 or date == ''

      symbol_code = _code_to_symbol(code)
      raise 'invalid code' if symbol_code == "" 


      url = sprintf(TICK_PRICE_URL, P_TYPE["http"], DOMAINS["sf"], PAGES["dl"], date, symbol_code)
      puts url 

      resp = HTTParty.get(url)
      if resp.code.to_s == "200"
        tb_value = resp.body.encode("utf-8", "gbk")
        CSV.new(tb_value, :headers => :first_row, encoding: 'utf-8', :col_sep => "\t").map {|a| Hash[ TICK_COLUMNS.zip(a.fields) ] }
      else 
        []
      end

    end 
    #  """
    #      获取sina大单数据
    #  Parameters
    #  ------
    #      code:string
    #                股票代码 e.g. 600848
    #      date:string
    #                日期 format：YYYY-MM-DD
    #      retry_count : int, 默认 3
    #                如遇网络等问题重复执行的次数
    #      pause : int, 默认 0
    #               重复请求数据过程中暂停的秒数，防止请求间隔时间太短出现的问题
    #   return
    #   -------
    #      DataFrame 当日所有股票交易数据(DataFrame)
    #            属性:股票代码    股票名称    交易时间    价格    成交量    前一笔价格    类型（买、卖、中性盘）
    #  """
    def get_sina_dd(code, options = {})
      return nil if code.nil? or code.size != 6 
      symbol_code = _code_to_symbol(code)
      raise 'invalid code' if symbol_code == ""       
      
      options = {date: Time.now.strftime("%Y-%m-%d"), vol: 400}.merge(options)

      vol = options[:vol] * 100
      url = sprintf(SINA_DD, P_TYPE["http"], DOMAINS["vsf"], PAGES["sinadd"], symbol_code, vol, options[:date])
      resp = HTTParty.get(url)
      if resp.code.to_s == "200"
        val = resp.body.encode("utf-8", "gbk")
        CSV.new(val, :headers => :first_row, encoding: 'utf-8', :col_sep => ",").map do |a|   
          fields = a.fields 
          fields[0] = fields[0][2, fields.size - 1]
          Hash[ SINA_DD_COLS.zip(fields) ]
        end
      else 
        []
      end


    end 

  end 

end
