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
        fn                = File.join(settings.dm_reports_location, '.dm_report_list.yml')
        report_dictionary = YAML.load_file(fn)
        this_report       = report_dictionary[id.to_i]
        yp                = Dataminer::YamlPersistor.new(this_report[:file])
        Dataminer::Report.load(yp)
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
        
        def menu
          "<p>[#{settings.url_prefix}]<a href='/#{settings.url_prefix}index'>Index</a></p>"
        end
      end


      get '/' do
        dataset = DB['select id from users']
        "GOT THERE... running with #{settings.appname} <a href='#{settings.url_prefix}test_page'>Go to test page</a><p>Users: #{dataset.count} with ids: #{dataset.map(:id).join(', ')}.</p><p>Random user: #{DB['select user_name FROM users LIMIT 1'].first[:user_name]}</p>"
      end

      get '/index' do
        ymlfiles = File.join(settings.dm_reports_location, "**", "*.yml")
        yml_list = Dir.glob( ymlfiles )#.map {|l| l.split('/')[1..99].join('/')} # Remove top-level of path.
        rpt_list = []
        rpt_set  = {}
        yml_list.each_with_index do |yml_file, index|
          yp = Dataminer::YamlPersistor.new(yml_file)
          rpt_list << {id: index, file: yml_file, caption: Dataminer::Report.load(yp).caption }
          rpt_set[index] = { file: yml_file, caption: Dataminer::Report.load(yp).caption }
        end
        File.open(File.join(settings.dm_reports_location, '.dm_report_list.yml'), 'w') { |f| YAML.dump(rpt_set, f) }
        # TODO: sort report list, group, add tags etc...

        <<-EOS
        <h1>Dataminer Reports</h1><p>#{yml_list.join('<br>')}</p>
        <ol><li>#{rpt_list.map {|r| "<a href='/#{settings.url_prefix}report/#{r[:id]}'>#{r[:caption]}</a>" }.join('</li><li>')}</li></ol>
        EOS
        # <ul><li>#{rpt_set.map {|k,v| "#{k}: #{v}" }.join('</li><li>')}</li></ul>
        # <pre>#{File.read(File.join(settings.dm_reports_location, '.dm_report_list.yml'))}</pre>
      end

      get '/report/:id' do
        # fn = File.join(settings.dm_reports_location, '.dm_report_list.yml')
        # report_dictionary = YAML.load_file(fn)
        # this_report = report_dictionary[params[:id].to_i]
        # yp = Dataminer::YamlPersistor.new(this_report[:file])
        # rpt = Dataminer::Report.load(yp)
        rpt = lookup_report(params[:id])

        # repos = DmRepository.new
        # rpt = repos.get_report(params[:id].to_i)
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
        @qps = rpt.query_parameter_definitions
        #<%= @ops_text % qp[:column] %>
        # input types: text, date, datetime-local, number
        # month, week, time
        erb <<-EOS
  <h1>Fill in params</h1>#{menu}
  <form action='/#{settings.url_prefix}run_rpt#{params[:id]}' method=post>Report: #{rpt.caption}<br>
  <% @qps.each do |qp| %>
    <p><label><%=qp.caption %>
    <select name="queryparam[<%=qp.column %>][operator]">
    <% if qp.control_type == :list %>
      <%= make_options(@ops_sel_ar)%>
    <% elsif qp.control_type == :date %>
      <%= make_options(@ops_date_ar)%>
    <% else %>
      <%= make_options(@ops_ar)%>
    <% end %>
    </select>
    <% if qp.control_type == :list %>
      <select name="queryparam[<%=qp.column %>][value]">
      <option value=""></option>
        <%= make_options(qp.build_list {|sql| DB[sql].all.map {|r| r.values } }.list_values) %>
      </select>
    <% elsif qp.control_type == :date %>
      <input type="date" name="queryparam[<%=qp.column %>][from_value]" value="<%=qp.default_value %>" />
      and
      <input type="date" name="queryparam[<%=qp.column %>][to_value]" value="<%=qp.default_value %>" />
    <% else %>
      <input type="text" name="queryparam[<%=qp.column %>][value]" value="<%=qp.default_value %>" />
    <% end %>
    </label>
    </p>
  <% end %>
  <p><label>Limit: <input type="number" name='limit' min="1" /></label>
  <p><input type=submit></p>
  </form>
        EOS

      end

      post '/run_rpt:id' do
        #"PARAMS: #{params.inspect}"
        # PARAMS: {"queryparam" => {"user_name"=>{"operator"=>"=", "value"=>"sd"}, "department_id"=>{"operator"=>"=", "value"=>"17"}, "created_by"=>{"operator"=>"=", "value"=>"hans"}, "created_at"=>{"operator"=>"<", "value"=>"2015-10-08"}}, "limit"=>"", "splat"=>[], "captures"=>["1"], "id"=>"1"}
        #
        # How to handle IN (n,n,n,n,n)...
        # qparam => {username =>{1=>{op,val},2=>{op,val}},department_id =>{1=>{op,val},2=>{op,val}},created_at=>{op=>"between",from=>"",to=>""}}
        #
        # NOTES ------------------
        # validate if between chosen, must have from && to values... (should do this in the UI)
        # ------------------------

        # fn = File.join(settings.dm_reports_location, '.dm_report_list.yml')
        # report_dictionary = YAML.load_file(fn)
        # this_report = report_dictionary[params[:id].to_i]
        # yp = Dataminer::YamlPersistor.new(this_report[:file])
        # rpt = Dataminer::Report.load(yp)
        @rpt = lookup_report(params[:id])
        # repos = DmRepository.new
        # rpt = repos.get_report(params[:id].to_i)
        # yp = Dataminer::YamlPersistor.new('tst.yml')
        # rpt = Dataminer::Report.load(yp)
        # rpt = Dataminer::Report.create_from_hash(YAML.load(File.read('tst.yml')))

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
            # opts = {:operator => rules['operator'], :value => rules['value'] || rules['from_value']}
            #puts col.data_type
            # if :integer == col && col.data_type
            #   opts[:convert] = :to_i
            # end
            # dtype = :integer #col && col.data_type
            dtype = :string
            @rpt.query_parameter_definitions.each {|d| if d.column == field then dtype = d.data_type; end }
            #parms << Dataminer::QueryParameter.new(pn, opts)
            parms << Dataminer::QueryParameter.new(pn, Dataminer::OperatorValue.new(rules['operator'], rules['value'] || rules['to_value'], dtype))
          end
        end
        # puts parms.inspect

        @rpt.limit = params[:limit].to_i if params[:limit] != ''
        # rpt.offset = params[:offset].to_i if params[:offset] != ''
        begin
          @rpt.apply_params(parms)
        rescue StandardError => e
          return "ERROR: #{e.message}"
        end


        #res = ActiveRecord::Base.connection.select_all(rpt.runnable_sql)
        res = DB[@rpt.runnable_sql].all

        tab = "<table border='1'><tr>#{@rpt.ordered_columns.map {|c| "<th>#{c.caption}</th>" }.join}</tr>"
        res.each do |r|
          tab << '<tr>'
          @rpt.ordered_columns.each {|c| tab << "<td#{if c.data_type==:integer || c.data_type==:number then ' align="right"'; end}>#{r[c.name.to_sym]}</td>" }
          tab << '</tr>'
        end
        tab << '</table>'
        #pg = PgQuery.parse(rpt.runnable_sql)
        # show_hide = %Q|
        #   <a href="#" onclick="var post = document.getElementById('debug_info'); if(post.style.display === 'none') { post.style.display = 'block';} else {post.style.display = 'none';};return false">Show SQL and parse tree &#10162;</a>
        #   <div id="debug_info" style="display : none;">
        #   <p>#{pg.tree[0]}</p>LIMIT: #{rpt.limit}.
        #   </div>|


        # "<h1>Report results &ndash; RESULT</h1>#{menu}<pre>#{sql_to_highlight(@rpt.runnable_sql)}</pre><hr>
        # #{tab}"
        # + "<h2>Columns</h2><table><tr><th>Name</th><th>Seq</th><th>Caption</th><th>Namespace</th></tr>#{rpt.columns.map {|c| "<tr><td>#{c.name}</td><td>#{c.sequence_no}</td><td>#{c.caption}</td><td>#{c.namespaced_name}</td></tr>" }.join("\n")}</table>"
        erb :report_display
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
