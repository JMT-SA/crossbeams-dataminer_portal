#TODO: This should probably be changed to use Sinatra::Base so that Object is not poulted with Sinatra methods...
require 'sinatra'
require 'sinatra/contrib'
require 'sequel'

module FloatingCanvas
  module DataminerPortal

    class ConfigMerger
      # Write a new config file by applying the client-specific settings over the defaults.
      def self.merge_config_files(base_file, over_file, new_config_file_name)
        f = File.open(new_config_file_name, 'w')
        YAML.dump(YAML.load_file(base_file).merge(YAML.load_file(over_file)), f)
        f.close

        hold = File.readlines(new_config_file_name)[1..-1].join
        File.open(new_config_file_name,"w") {|fw| fw.write(hold) }
      end
    end

    class WebPortal < Sinatra::Application

      configure do
        enable :logging
        # mkdir log if it does not exist...
        Dir.mkdir('log') unless Dir.exist?('log')
        file = File.new("log/dm_#{settings.environment}.log", 'a+')
        file.sync = true
        use Rack::CommonLogger, file

        set :environment, :production
        set :root, File.dirname(__FILE__)
        # :method_override - use for PATCH etc forms? http://www.rubydoc.info/github/rack/rack/Rack/MethodOverride
        set :app_file, __FILE__
        # :raise_errors - should be set so that Rack::ShowExceptions or the server can be used to handle the error...
        enable :show_exceptions # because we are forcing the environment to production...
        set :appname, 'tst'
        set :url_prefix, ENV['DM_PREFIX']  ? "#{ENV['DM_PREFIX']}/" : ''
        set :protection, except: :frame_options # so it can be loaded in another app's iframe...


        set :base_file, "#{FileUtils.pwd}/config/dm_defaults.yml"
        set :over_file, "#{FileUtils.pwd}/config/dm_#{ENV['DM_CLIENT'] || 'defaults'}.yml"
        set :new_config_file_name, "#{FileUtils.pwd}/config/dm_config_file.yml" # This could be a StringIO...
      end

      if settings.base_file == settings.over_file
        FileUtils.cp(settings.base_file, settings.new_config_file_name)
      else
        ConfigMerger.merge_config_files(settings.base_file, settings.over_file, settings.new_config_file_name)
      end
      config_file settings.new_config_file_name

      # TODO: Need to see how this should be done when running under passenger/thin/puma...
      DB = Sequel.postgres(settings.database['name'], :user => settings.database['user'], :password => settings.database['password'], :host => settings.database['host'] || 'localhost')


      def sql_to_highlight(sql)
        # wrap sql @ 120
        width = 120
        ar = sql.gsub(/from /i, "\nFROM ").gsub(/where /i, "\nWHERE ").gsub(/(left outer join |left join |inner join |join )/i, "\n\\1").split("\n")
        wrapped_sql = ar.map {|a| a.scan(/\S.{0,#{width-2}}\S(?=\s|$)|\S+/).join("\n") }.join("\n")
        # wrapped_sql = sql.scan(/\S.{0,#{width-2}}\S(?=\s|$)|\S+/).join("\n")
        # opts = {:css_class    => nil,
        #         :inline_theme => 'github',
        #         :line_numbers => false}

        theme = Rouge::Themes::Github.new
        formatter = Rouge::Formatters::HTMLInline.new(theme)
        #lexer  = Rouge::Lexer.find('sql')
        lexer  = Rouge::Lexers::SQL.new
        formatter.format(lexer.lex(wrapped_sql))
      end

      def lookup_report(id)
        DmReportLister.new(settings.dm_reports_location).get_report_by_id(id)
      end

      def clean_where(sql)
        rems = sql.scan( /\{(.+?)\}/).flatten.map {|s| "#{s}={#{s}}" }
        rems.each {|r| sql.gsub!(%r|and\s+#{r}|i,'') }
        rems.each {|r| sql.gsub!(r,'') }
        sql.sub!(/where\s*\(\s+\)/i, '')
        sql
      end


      # ERB helpers.
      helpers do
        # def h(text)
        #   Rack::Utils.escape_html(text)
        # end
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

        def menu
          "<p><a href='/#{settings.url_prefix}index'>Return to report index</a></p>"
        end
      end


      get '/' do
        # dataset = DB['select id from users']
        # "GOT THERE... running with #{settings.appname} <a href='#{settings.url_prefix}test_page'>Go to test page</a><p>Users: #{dataset.count} with ids: #{dataset.map(:id).join(', ')}.</p><p>Random user: #{DB['select user_name FROM users LIMIT 1'].first[:user_name]}</p>"
        "<a href='/#{settings.url_prefix}index'>DATAMINER REPORT INDEX</a>"
      end

      get '/index' do
        # TODO: sort report list, group, add tags etc...

        rpt_list = DmReportLister.new(settings.dm_reports_location).get_report_list(true)

        <<-EOS
        <h1>Dataminer Reports</h1>
        <ol><li>#{rpt_list.map {|r| "<a href='/#{settings.url_prefix}report/#{r[:id]}'>#{r[:caption]}</a>" }.join('</li><li>')}</li></ol>
        EOS
      end

      get '/report/:id' do
        # fn = File.join(settings.dm_reports_location, '.dm_report_list.yml')
        # report_dictionary = YAML.load_file(fn)
        # this_report = report_dictionary[params[:id].to_i]
        # yp = Dataminer::YamlPersistor.new(this_report[:file])
        # @rpt = Dataminer::Report.load(yp)
        @rpt = lookup_report(params[:id])

        # repos = DmRepository.new
        # @rpt = repos.get_report(params[:id].to_i)
        #TODO: involve DB in calcing list contents
        @ops_text = <<-EOP
<select name="%s_operator">
  <option value="=">is</option>
  <option value="<>">is not</option>
  <option value=">">greater than</option>
  <option value="<">less than</option>
  <option value=">=">greater than or equal to</option>
  <option value="<=">less than or equal to</option>
  <option value="is_null">is blank</option>
  <option value="not_null">is NOT blank</option>
  <option value="starts_with">starts with</option>
  <option value="ends_with">ends with</option>
  <option value="contains">contains</option>
</select>
        EOP
        @ops_ar = [
          ['is', "="],
          ['is not', "<>"],
          ['greater than', ">"],
          ['less than', "<"],
          ['greater than or equal to', ">="],
          ['less than or equal to', "<="],
          ['is blank', "is_null"],
          ['is NOT blank', "not_null"],
          ['starts with', "starts_with"],
          ['ends with', "ends_with"],
          ['contains', "contains"]]
        @ops_sel_ar = [
          ['is', "="],
          ['is not', "<>"],
          ['greater than', ">"],
          ['less than', "<"],
          ['greater than or equal to', ">="],
          ['less than or equal to', "<="],
          ['is blank', "is_null"],
          ['is NOT blank', "not_null"]]
        @ops_date_ar = [
          ['between', "between"],
          ['is', "="],
          ['is not', "<>"],
          ['greater than', ">"],
          ['less than', "<"],
          ['greater than or equal to', ">="],
          ['less than or equal to', "<="],
          ['is blank', "is_null"],
          ['is NOT blank', "not_null"]]
        # for date, s.b. between
        # for list, all but start,end,contain...
        @qps = @rpt.query_parameter_definitions
        #<%= @ops_text % qp[:column] %>
        # input types: text, date, datetime-local, number
        # month, week, time

        @menu = menu
        @report_action = "/#{settings.url_prefix}run_rpt/#{params[:id]}"

        erb :report_parameters
      end

      # Return a grid with the report.
      post '/run_rpt/:id' do
        # How to handle IN (n,n,n,n,n)...
        # qparam => {username =>{1=>{op,val},2=>{op,val}},department_id =>{1=>{op,val},2=>{op,val}},created_at=>{op=>"between",from=>"",to=>""}}
        #
        # NOTES ------------------
        # validate if between chosen, must have from && to values... (should do this in the UI)
        # ------------------------

        @rpt = lookup_report(params[:id])

        in_params = params[:queryparam]
        parms = []
        in_params.each do |field,rules|
          col = @rpt.column(field)
          pn = col.nil? ? field : col.namespaced_name # should be from QparamDef...
          #puts col && col.data_type
          if 'between' == rules['operator']
            unless rules['from_value'] == '' && rules['to_value'] == ''
              # parms << Dataminer::QueryParameter.new(pn, :operator => rules['operator'], :from_value => rules['from_value'], :to_value => rules['to_value'])
              parms << Dataminer::QueryParameter.new(pn, Dataminer::OperatorValue.new(rules['operator'], [rules['from_value'], rules['to_value']]))
            end
          else
            next if rules['value'] == '' && rules['operator'] != 'is_null' && rules['operator'] != 'not_null'
            # , :convert => :to_i
            #FIXME: param might not be part of returned columns - use param def to decide datatype.
            #- rpt has param defs & new params apply to them, BUT should allow for new params that do not relate to param defs
            #- when replacing WHERE with ID for e.g.
            dtype = :string
            @rpt.query_parameter_definitions.each {|d| if d.column == field then dtype = d.data_type; end }
            parms << Dataminer::QueryParameter.new(pn, Dataminer::OperatorValue.new(rules['operator'], rules['value'] || rules['to_value'], dtype))
          end
        end

        @rpt.limit = params[:limit].to_i if params[:limit] != ''
        # rpt.offset = params[:offset].to_i if params[:offset] != ''
        begin
          @rpt.apply_params(parms)
        rescue StandardError => e
          return "ERROR: #{e.message}"
        end

        @col_defs = []
        @rpt.ordered_columns.each do | col|
          hs                  = {headerName: col.caption, field: col.name, hide: col.hide, headerTooltip: col.caption}
          hs[:width]          = col.width unless col.width.nil?
          hs[:enableValue]    = true if [:integer, :number].include?(col.data_type)
          hs[:enableRowGroup] = true unless hs[:enableValue]
          if [:integer, :number].include?(col.data_type)
            hs[:cellClass] = 'grid-number-column'
            hs[:width]     = 100 if col.width.nil? && col.data_type == :integer
            hs[:width]     = 120 if col.width.nil? && col.data_type == :number
          end
          if col.format == :delimited_1000
            hs[:cellRenderer] = 'jmtGridFormatters.numberWithCommas2'
          end
          if col.format == :delimited_1000_4
            hs[:cellRenderer] = 'jmtGridFormatters.numberWithCommas4'
          end
          if col.data_type == :boolean
            hs[:cellRenderer] = 'jmtGridFormatters.booleanFormatter'
            hs[:cellClass]    = 'grid-boolean-column'
            hs[:width]        = 100 if col.width.nil?
          end

          hs[:cellClassRules] = {"grid-row-red": "x === 'Fred'"} if col.name == 'author'

          @col_defs << hs
        end

        @row_defs = DB[@rpt.runnable_sql].all

        erb :report_display
      end

      get '/admin' do
        # Need some kind of login verification.
        # List reports for editing.
        # Button to import old-style report.
        # Button to create new report.
        # "NOT YET WRITTEN..."
        @rpt_list = DmReportLister.new(settings.dm_reports_location).get_report_list(from_cache: true)
        erb :admin_index
      end

      post '/admin_convert' do
        unless params[:file] &&
               (tmpfile = params[:file][:tempfile]) &&
               (name = params[:file][:filename])
          return "No file selected"
        end
        yml = tmpfile.read
        hash = YAML.load(yml)
        <<-EOS
        <h1>FILE: #{name}</h1>#{menu}
        
        <form action='/#{settings.url_prefix}set_sql' method=post>
        <input type='hidden' name='filename' value='#{name}' />
        <input type='hidden' name='temp_path' value='#{tmpfile.path}' />
        SQL: <textarea name=sql rows=20 cols=120>#{clean_where(hash['query'])}</textarea>
        <p><strong>NB</strong> remove all <em>column={column}</em> parts of the WHERE clause before converting.
        <br>This code tries to do as much as possible, but you need to check the where clause - especially for stray "and"s.</p>
        <br><input type='submit' />
        </form>
        <pre>#{yml}</pre>
        EOS
      end

      post '/set_sql' do
        yml = nil
        File.open(params[:temp_path], 'r') {|f| yml = f.read }
        hash = YAML.load(yml)
        hash['query'] = params[:sql]
        rpt = DmConverter.new(settings.dm_reports_location).convert_hash(hash, params[:filename])
        # yp = Dataminer::YamlPersistor.new('report1.yml')
        # rpt.save(yp)
        <<-EOS
        <h1>Converted</h1>#{menu}
        <pre>#{rpt.to_hash.to_yaml}</pre>
        EOS
      end


      get '/test_page' do
        erb :test
      end
    end

  end

end
# Could we have two dm's connected to different databases?
# ...and store each set of yml files in different dirs.
# --- how to use the same gem twice on diferent routes?????
#
