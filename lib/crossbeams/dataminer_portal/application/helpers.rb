require 'sinatra/base'
module Sinatra
  module DataminerPortalHelpers
    extend Sinatra::Extension

    def sql_to_highlight(sql)
      # wrap sql @ 120
      width = 120
      ar = sql.gsub(/from /i, "\nFROM ").gsub(/where /i, "\nWHERE ").gsub(/(left outer join |left join |inner join |join )/i, "\n\\1").split("\n")
      wrapped_sql = ar.map {|a| a.scan(/\S.{0,#{width-2}}\S(?=\s|$)|\S+/).join("\n") }.join("\n")

      theme = Rouge::Themes::Github.new
      formatter = Rouge::Formatters::HTMLInline.new(theme)
      lexer  = Rouge::Lexers::SQL.new
      formatter.format(lexer.lex(wrapped_sql))
    end

    def yml_to_highlight(yml)
      theme = Rouge::Themes::Github.new
      formatter = Rouge::Formatters::HTMLInline.new(theme)
      lexer  = Rouge::Lexers::YAML.new
      formatter.format(lexer.lex(yml))
    end

    # TODO: Change this to work from filenames.
    def lookup_report(id)
      Crossbeams::DataminerPortal::DmReportLister.new(settings.dm_reports_location).get_report_by_id(id)
    end

    def clean_where(sql)
      rems = sql.scan( /\{(.+?)\}/).flatten.map {|s| "#{s}={#{s}}" }
      rems.each {|r| sql.gsub!(%r|and\s+#{r}|i,'') }
        rems.each {|r| sql.gsub!(r,'') }
      sql.sub!(/where\s*\(\s+\)/i, '')
      sql
    end

    def setup_report_with_parameters(rpt, params)
      #{"col"=>"users.department_id", "op"=>"=", "opText"=>"is", "val"=>"17", "text"=>"Finance", "caption"=>"Department"}
      input_parameters = ::JSON.parse(params[:json_var])
      # logger.info input_parameters.inspect
      parms = []
      # Check if this should become an IN parmeter (list of equal checks for a column.
      eq_sel = input_parameters.select { |p| p['op'] == '=' }.group_by { |p| p['col'] }
      in_sets = {}
      in_keys = []
      eq_sel.each do |col, qp|
        in_keys << col if qp.length > 1
      end

      input_parameters.each do |in_param|
        col = in_param['col']
        if in_keys.include?(col)
          in_sets[col] ||= []
          in_sets[col] << in_param['val']
          next
        end
        param_def = @rpt.parameter_definition(col)
        if 'between' == in_param['op']
          parms << Crossbeams::Dataminer::QueryParameter.new(col, Crossbeams::Dataminer::OperatorValue.new(in_param['op'], [in_param['val'], in_param['val_to']], param_def.data_type))
        else
          parms << Crossbeams::Dataminer::QueryParameter.new(col, Crossbeams::Dataminer::OperatorValue.new(in_param['op'], in_param['val'], param_def.data_type))
        end
      end
      in_sets.each do |col, vals|
        param_def = @rpt.parameter_definition(col)
        parms << Crossbeams::Dataminer::QueryParameter.new(col, Crossbeams::Dataminer::OperatorValue.new('in', vals, param_def.data_type))
      end

      rpt.limit  = params[:limit].to_i  if params[:limit] != ''
      rpt.offset = params[:offset].to_i if params[:offset] != ''
      begin
        rpt.apply_params(parms)
      rescue StandardError => e
        return "ERROR: #{e.message}"
      end
    end

    def make_options(ar)
      ar.map do |a|
        if a.kind_of?(Array)
          "<option value=\"#{a.last}\">#{a.first}</option>"
        else
          "<option value=\"#{a}\">#{a}</option>"
        end
      end.join("\n")
    end

    def the_url_prefix
      settings.url_prefix
    end

    def menu(options = {})
      admin_menu = options[:with_admin] ? " | <a href='/#{settings.url_prefix}admin'>Return to admin index</a>" : ''
      back_menu  = options[:return_to_report] ? " | <a href='#{options[:return_action]}?back=y'>Back</a>" : ''
      "<p><a href='/#{settings.url_prefix}index'>Return to report index</a>#{admin_menu}#{back_menu}</p>"
    end

    def h(text)
      Rack::Utils.escape_html(text)
    end

    def select_options(value, opts, with_blank = true)
      ar = []
      ar << "<option value=''></option>" if with_blank
      opts.each do |opt|
        if opt.kind_of? Array
          text, val = opt
        else
          val = opt
          text  = opt
        end
        is_sel = val.to_s == value.to_s
        ar << "<option value='#{val}'#{is_sel ? ' selected' : ''}>#{text}</option>"
      end
      ar.join("\n")
    end

    def make_query_param_json(query_params)
      common_ops = [
        ['is', "="],
        ['is not', "<>"],
        ['greater than', ">"],
        ['less than', "<"],
        ['greater than or equal to', ">="],
        ['less than or equal to', "<="],
        ['is blank', "is_null"],
        ['is NOT blank', "not_null"]
      ]
      text_ops = [
        ['starts with', "starts_with"],
        ['ends with', "ends_with"],
        ['contains', "contains"]
      ]
      date_ops = [
        ['between', "between"]
      ]
      # ar = []
      qp_hash = {}
      query_params.each do |query_param|
        hs = {column: query_param.column, caption: query_param.caption,
              default_value: query_param.default_value, data_type: query_param.data_type,
              control_type: query_param.control_type}
        if query_param.control_type == :list
          hs[:operator] = common_ops
          if query_param.includes_list_options?
            hs[:list_values] = query_param.build_list.list_values
          else
            hs[:list_values] = query_param.build_list {|sql| Crossbeams::DataminerPortal::DB[sql].all.map {|r| r.values } }.list_values
          end
        elsif query_param.control_type == :daterange
          hs[:operator] = date_ops + common_ops
        else
          hs[:operator] = common_ops + text_ops
        end
        # ar << hs
        qp_hash[query_param.column] = hs
      end
      # ar.to_json
      qp_hash.to_json
    end

  end
  helpers DataminerPortalHelpers
end
