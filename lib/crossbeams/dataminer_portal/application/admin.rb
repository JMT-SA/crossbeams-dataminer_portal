module Crossbeams
  module DataminerPortal
    module Admin
      extend Sinatra::Extension

      get '/admin' do
        # Need some kind of login verification.
        # List reports for editing.
        # Button to import old-style report.
        # Button to create new report.
        # "NOT YET WRITTEN..."
        @rpt_list = DmReportLister.new(settings.dm_reports_location).get_report_list(from_cache: true)
        @menu     = menu
        erb :'admin/index'
      end

      post '/admin/convert' do
        unless params[:file] &&
               (@tmpfile = params[:file][:tempfile]) &&
               (@name = params[:file][:filename])
          return "No file selected"
        end
        @yml  = @tmpfile.read
        @hash = YAML.load(@yml)
        @menu =  menu(with_admin: true)
        erb :'admin/convert'
      end

      post '/admin/save_conversion' do
        yml = nil
        File.open(params[:temp_path], 'r') {|f| yml = f.read }
        hash = YAML.load(yml)
        hash['query'] = params[:sql]
        rpt = DmConverter.new(settings.dm_reports_location).convert_hash(hash, params[:filename])
        # yp = Crossbeams::Dataminer::YamlPersistor.new('report1.yml')
        # rpt.save(yp)
        erb(<<-EOS)
        <h1>Converted</h1>#{menu(with_admin: true)}
        <p>New YAML code:</p>
        <pre>#{yml_to_highlight(rpt.to_hash.to_yaml)}</pre>
        EOS
      end

      get '/admin/new' do
        @filename=''
        @caption=''
        @sql=''
        @err=''
        erb :'admin/new'
      end

      post '/admin/create' do
        #@filename = params[:filename].trim.downcase.tr(' ', '_').gsub(/_+/, '_')
        # Ensure the filename:
        # * is lowercase
        # * has spaces converted to underscores
        # * more than one underscore in a row becomes one
        # * the name ends in ".yml"
        s = params[:filename].strip.downcase.tr(' ', '_').gsub(/_+/, '_').gsub(/[\/:*?"\\<>\|\r\n]/i, '-')
        @filename = File.basename(s).reverse.sub(File.extname(s).reverse, '').reverse << '.yml'
        @caption  = params[:caption]
        @sql      = params[:sql]
        @err      = ''

        @rpt = Crossbeams::Dataminer::Report.new(@caption)
        begin
          @rpt.sql = @sql
        rescue StandardError => e
          @err = e.message
        end
        # Check for existing file name...
        if File.exists?(File.join(settings.dm_reports_location, @filename))
          @err = 'A file with this name already exists'
        end
        # Write file, rebuild index and go to edit...

        if @err.empty?
          # run the report with limit 1 and set up datatypes etc.
          DmCreator.new(DB, @rpt).modify_column_datatypes
          yp = Crossbeams::Dataminer::YamlPersistor.new(File.join(settings.dm_reports_location, @filename))
          @rpt.save(yp)
          DmReportLister.new(settings.dm_reports_location).get_report_list(persist: true) # Kludge to ensure list is rebuilt... (stuffs up anyone else running reports if id changes....)

          erb(<<-EOS)
          <h1>Saved file...got to admin index and edit...</h1>#{menu(with_admin: true)}
          <p>Filename: <em><%= @filename %></em></p>
          <p>Caption: <em><%= @rpt.caption %></em></p>
          <p>SQL: <em><%= @rpt.runnable_sql %></em></p>
          <p>Columns:<br><% @rpt.columns.each do | column| %>
            <p><%= column %></p>
          <% end %>
          </p>
          EOS
        else
          erb :'admin/new'
        end
      end

      get '/admin/edit/:id' do
        @rpt = lookup_report(params[:id])
        @filename = File.basename(DmReportLister.new(settings.dm_reports_location).get_file_name_by_id(params[:id]))

        @col_defs = [{headerName: 'Column Name', field: 'name'},
                     {headerName: 'Sequence', field: 'sequence_no', cellClass: 'grid-number-column'}, # to be changed in group...
                     {headerName: 'Caption', field: 'caption', editable: true},
                     {headerName: 'Namespaced Name', field: 'namespaced_name'},
                     {headerName: 'Data type', field: 'data_type', editable: true, cellEditor: 'select', cellEditorParams: {
                       values: ['string', 'integer', 'number', 'date', 'datetime']
                     }},
                     {headerName: 'Width', field: 'width', cellClass: 'grid-number-column', editable: true, cellEditor: 'NumericCellEditor'}, # editable NUM ONLY...
                     {headerName: 'Format', field: 'format', editable: true, cellEditor: 'select', cellEditorParams: {
                       values: ['', 'delimited_1000', 'delimited_1000_4']
                     }},
                     {headerName: 'Hide?', field: 'hide', cellRenderer: 'crossbeamsGridFormatters.booleanFormatter', cellClass: 'grid-boolean-column', editable: true, cellEditor: 'select', cellEditorParams: {
                       values: [true, false]
                     }},
                     {headerName: 'Can group by?', field: 'groupable', cellRenderer: 'crossbeamsGridFormatters.booleanFormatter', cellClass: 'grid-boolean-column', editable: true, cellEditor: 'select', cellEditorParams: {
                       values: [true, false]
                     }},
                     {headerName: 'Group Seq', field: 'group_by_seq', cellClass: 'grid-number-column', headerTooltip: 'If the grid opens grouped, this is the grouping level', editable: true, cellEditor: 'select', cellEditorParams: {
                       values: [true, false]
                     }},
                     {headerName: 'Sum?', field: 'group_sum', cellRenderer: 'crossbeamsGridFormatters.booleanFormatter', cellClass: 'grid-boolean-column', editable: true, cellEditor: 'select', cellEditorParams: {
                       values: [true, false]
                     }},
                     {headerName: 'Avg?', field: 'group_avg', cellRenderer: 'crossbeamsGridFormatters.booleanFormatter', cellClass: 'grid-boolean-column', editable: true, cellEditor: 'select', cellEditorParams: {
                       values: [true, false]
                     }},
                     {headerName: 'Min?', field: 'group_min', cellRenderer: 'crossbeamsGridFormatters.booleanFormatter', cellClass: 'grid-boolean-column', editable: true, cellEditor: 'select', cellEditorParams: {
                       values: [true, false]
                     }},
                     {headerName: 'Max?', field: 'group_max', cellRenderer: 'crossbeamsGridFormatters.booleanFormatter', cellClass: 'grid-boolean-column', editable: true, cellEditor: 'select', cellEditorParams: {
                       values: [true, false]
                     }}
        ]
        @row_defs = @rpt.ordered_columns.map {|c| c.to_hash }

        @col_defs_params = [
          {headerName: '', width: 60, suppressMenu: true, suppressSorting: true, suppressMovable: true, suppressFilter: true,
           enableRowGroup: false, enablePivot: false, enableValue: false, suppressCsvExport: true,
           valueGetter: "'/#{settings.url_prefix}admin/delete_param/#{params[:id]}/' + data.column + '|delete|Are you sure?|delete'", colId: 'delete_link', cellRenderer: 'crossbeamsGridFormatters.hrefPromptFormatter'},

          {headerName: 'Column', field: 'column'},
          {headerName: 'Caption', field: 'caption'},
          {headerName: 'Data type', field: 'data_type'},
          {headerName: 'Control type', field: 'control_type'},
          {headerName: 'List definition', field: 'list_def'},
          {headerName: 'UI priority', field: 'ui_priority'},
          {headerName: 'Default value', field: 'default_value'}#,
          #{headerName: 'List values', field: 'list_values'}
        ]

        @row_defs_params = []
        @rpt.query_parameter_definitions.each do |query_def|
          @row_defs_params << query_def.to_hash
        end
        @save_url = "/#{settings.url_prefix}admin/save_param_grid_col/#{params[:id]}"
        erb :'admin/edit'
      end

      #TODO:
      #      - Make JS scoped by crossbeams.
      #      - split editors into another JS file
      #      - ditto formatters etc...
      post '/admin/save_param_grid_col/:id' do
        content_type :json

        @rpt = lookup_report(params[:id])
        col = @rpt.columns[params[:key_val]]
        attrib = params[:col_name]
        value  = params[:col_val]
        value  = nil if value.strip == ''
        # Should validate - width numeric, range... caption cannot be blank...
        # group_sum, avg etc should act as radio grps... --> Create service class to do validation.
        # FIXME: width cannot be 0...
        if ['format', 'data_type'].include?(attrib) && !value.nil?
          col.send("#{attrib}=", value.to_sym)
        else
          value = value.to_i if attrib == 'width' && !value.nil?
          col.send("#{attrib}=", value)
        end
        puts ">>> ATTR: #{attrib} - #{value} #{value.class}"
        if attrib == 'group_sum' && value == 'true' # NOTE string value of bool...
          puts 'CHANGING...'
          col.group_avg = false
          col.group_min = false
          col.group_max = false
          send_changes = true
        else
          send_changes = false
        end

        if value.nil? && attrib == 'caption' # Cannot be nil...
          {status: 'error', message: "Caption for #{params[:key_val]} cannot be blank"}.to_json
        else
          filename = DmReportLister.new(settings.dm_reports_location).get_file_name_by_id(params[:id])
          yp = Crossbeams::Dataminer::YamlPersistor.new(filename)
          @rpt.save(yp)
          if send_changes
            {status: 'ok', message: "Changed #{attrib} for #{params[:key_val]}",
             changedFields: {group_avg: false, group_min: false, group_max: false, group_none: 'A TEST'} }.to_json
          else
            {status: 'ok', message: "Changed #{attrib} for #{params[:key_val]}"}.to_json
          end
        end
      end

      get '/admin/new_parameter/:id' do
        @rpt = lookup_report(params[:id])
        @cols = @rpt.ordered_columns.map { |c| c.namespaced_name }.compact
        @tables = @rpt.tables
        erb :'admin/new_parameter'
      end

      post '/admin/create_parameter_def/:id' do
        # Validate... also cannot ad dif col exists as param already
        @rpt = lookup_report(params[:id])

        col_name = params[:column]
        if col_name.nil? || col_name.empty?
          col_name = "#{params[:table]}.#{params[:field]}"
        end
        opts = {:control_type => params[:control_type].to_sym,
                :data_type => params[:data_type].to_sym, caption: params[:caption]}
        unless params[:list_def].nil? || params[:list_def].empty?
          if params[:list_def].start_with?('[') # Array
            opts[:list_def] = eval(params[:list_def]) # TODO: unpack the string into an array... (Job for the gem?)
          else
            opts[:list_def] = params[:list_def]
          end
        end

        param = Crossbeams::Dataminer::QueryParameterDefinition.new(col_name, opts)
        @rpt.add_parameter_definition(param)

        filename = DmReportLister.new(settings.dm_reports_location).get_file_name_by_id(params[:id])
        yp = Crossbeams::Dataminer::YamlPersistor.new(filename)
        @rpt.save(yp)

        flash[:notice] = "Parameter has been added."
        redirect to("/#{settings.url_prefix}admin/edit/#{params[:id]}")
      end

      delete '/admin/delete_param/:rpt_id/:id' do
        @rpt = lookup_report(params[:rpt_id])
        id   = params[:id]
        # puts ">>> #{id}"
        # puts @rpt.query_parameter_definitions.length
        # puts @rpt.query_parameter_definitions.map { |p| p.column }.sort.join('; ')
        @rpt.query_parameter_definitions.delete_if { |p| p.column == id }
        # puts @rpt.query_parameter_definitions.length
        filename = DmReportLister.new(settings.dm_reports_location).get_file_name_by_id(params[:rpt_id])
        # puts filename
        yp = Crossbeams::Dataminer::YamlPersistor.new(filename)
        @rpt.save(yp)
        #puts @rpt.query_parameter_definitions.map { |p| p.column }.sort.join('; ')
        #params.inspect
        flash[:notice] = "Parameter has been deleted."
        redirect to("/#{settings.url_prefix}admin/edit/#{params[:rpt_id]}")
      end

      post '/admin/save_rpt_header/:id' do
        # if new name <> old name, make sure new name has .yml, no spaces and lowercase....
        @rpt = lookup_report(params[:id])

        filename = DmReportLister.new(settings.dm_reports_location).get_file_name_by_id(params[:id])
        if File.basename(filename) != params[:filename]
          puts "new name: #{params[:filename]} for #{File.basename(filename)}"
        else
          puts "No change to file name"
        end
        @rpt.caption = params[:caption]
        @rpt.limit = params[:limit].empty? ? nil : params[:limit].to_i
        @rpt.offset = params[:offset].empty? ? nil : params[:offset].to_i
        yp = Crossbeams::Dataminer::YamlPersistor.new(filename)
        @rpt.save(yp)

        # Need a flash here...
        flash[:notice] = "Report's header has been changed."
        redirect to("/#{settings.url_prefix}admin/edit/#{params[:id]}")
      end

      get '/admin/man' do
        "Got to Admin, Man"
      end
    end
  end
end
