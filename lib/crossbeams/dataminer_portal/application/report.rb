module Crossbeams
  module DataminerPortal
    module Report
      extend Sinatra::Extension

      get '/report/:id' do
        @rpt = lookup_report(params[:id])
        @qps = @rpt.query_parameter_definitions

        @menu = menu
        @report_action = "/#{settings.url_prefix}run_rpt/#{params[:id]}"
        @excel_action = "/#{settings.url_prefix}run_xls_rpt/#{params[:id]}"

        erb :'report/parameters'
      end

      # Return a grid with the report.
      post '/run_xls_rpt/:id' do
        @rpt = lookup_report(params[:id])
        setup_report_with_parameters(@rpt, params)

        begin
          xls_possible_types = {string: :string, integer: :integer, date: :string, datetime: :time, time: :time, boolean: :boolean, number: :float}
          heads = []
          fields = []
          xls_types = []
          x_styles = []
          Axlsx::Package.new do | p |
            p.workbook do | wb |
              styles     = wb.styles
              tbl_header = styles.add_style :b => true, :font_name => 'arial', :alignment => {:horizontal => :center}
              # red_negative = styles.add_style :num_fmt => 8
              delim4 = styles.add_style(:format_code=>"#,##0.0000;[Red]-#,##0.0000")
              delim2 = styles.add_style(:format_code=>"#,##0.00;[Red]-#,##0.00")
              and_styles = {delimited_1000_4: delim4, delimited_1000: delim2}
              @rpt.ordered_columns.each do | col|
                xls_types << xls_possible_types[col.data_type] || :string # BOOLEAN == 0,1 ... need to change this to Y/N...or use format TRUE|FALSE...
                heads << col.caption
                fields << col.name
                # x_styles << (col.format == :delimited_1000_4 ? delim4 : :delimited_1000 ? delim2 : nil) # :num_fmt => Axlsx::NUM_FMT_YYYYMMDDHHMMSS / Axlsx::NUM_FMT_PERCENT
                x_styles << and_styles[col.format]
              end
              puts x_styles.inspect
              wb.add_worksheet do | sheet |
                sheet.add_row heads, :style => tbl_header
                Crossbeams::DataminerPortal::DB[@rpt.runnable_sql].each do |row|
                  sheet.add_row(fields.map {|f| v = row[f.to_sym]; v.is_a?(BigDecimal) ? v.to_f : v }, :types => xls_types, :style => x_styles)
                end
              end
            end
            response.headers['content_type'] = "application/vnd.ms-excel"
            attachment(@rpt.caption.strip.gsub(/[\/:*?"\\<>\|\r\n]/i, '-') + '.xls')
            response.write(p.to_stream.read) # NOTE: could this streaming to start downloading quicker?
          end

        rescue Sequel::DatabaseError => e
          erb(<<-EOS)
          #{menu}<p style='color:red;'>There is a problem with the SQL definition of this report:</p>
          <p>Report: <em>#{@rpt.caption}</em></p>The error message is:
          <pre>#{e.message}</pre>
          <button class="pure-button" onclick="crossbeamsUtils.toggle_visibility('sql_code', this);return false">
            <i class="fa fa-info"></i> Toggle SQL
          </button>
          <pre id="sql_code" style="display:none;"><%= sql_to_highlight(@rpt.runnable_sql) %></pre>
          EOS
        end
      end

      post '/run_rpt/:id' do
        @rpt = lookup_report(params[:id])
        setup_report_with_parameters(@rpt, params)

        @col_defs = []
        @rpt.ordered_columns.each do | col|
          hs                  = {headerName: col.caption, field: col.name, hide: col.hide, headerTooltip: col.caption}
          hs[:width]          = col.width unless col.width.nil?
          hs[:enableValue]    = true if [:integer, :number].include?(col.data_type)
          hs[:enableRowGroup] = true unless hs[:enableValue] && !col.groupable
          hs[:enablePivot]    = true unless hs[:enableValue] && !col.groupable
          if [:integer, :number].include?(col.data_type)
            hs[:cellClass] = 'grid-number-column'
            hs[:width]     = 100 if col.width.nil? && col.data_type == :integer
            hs[:width]     = 120 if col.width.nil? && col.data_type == :number
          end
          if col.format == :delimited_1000
            hs[:cellRenderer] = 'crossbeamsGridFormatters.numberWithCommas2'
          end
          if col.format == :delimited_1000_4
            hs[:cellRenderer] = 'crossbeamsGridFormatters.numberWithCommas4'
          end
          if col.data_type == :boolean
            hs[:cellRenderer] = 'crossbeamsGridFormatters.booleanFormatter'
            hs[:cellClass]    = 'grid-boolean-column'
            hs[:width]        = 100 if col.width.nil?
          end

          # hs[:cellClassRules] = {"grid-row-red": "x === 'Fred'"} if col.name == 'author'

          @col_defs << hs
        end

        begin
          # Use module for BigDecimal change? - register_extension...?
          @row_defs = Crossbeams::DataminerPortal::DB[@rpt.runnable_sql].to_a.map {|m| m.keys.each {|k| if m[k].is_a?(BigDecimal) then m[k] = m[k].to_f; end }; m; }

          @return_action = "/#{settings.url_prefix}report/#{params[:id]}"
          erb :'report/display'

        rescue Sequel::DatabaseError => e
          erb(<<-EOS)
          #{menu}<p style='color:red;'>There is a problem with the SQL definition of this report:</p>
          <p>Report: <em>#{@rpt.caption}</em></p>The error message is:
          <pre>#{e.message}</pre>
          <button class="pure-button" onclick="crossbeamsUtils.toggle_visibility('sql_code', this);return false">
            <i class="fa fa-info"></i> Toggle SQL
          </button>
          <pre id="sql_code" style="display:none;"><%= sql_to_highlight(@rpt.runnable_sql) %></pre>
          EOS
        end
      end

    end
  end
end
