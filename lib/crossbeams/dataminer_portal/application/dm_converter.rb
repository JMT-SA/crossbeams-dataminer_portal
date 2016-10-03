module Crossbeams
  module DataminerPortal

    class DmConverter

      def initialize(path)
        @path = path
      end

      def convert_hash(hash, name)
        #...main_table_name, default_index_name...
        grid_configs = hash['grid_configs'] || {}
        hidden = grid_configs['hidden'] || {}
        groupable_fields = grid_configs['groupable_fields'] || []
        sum_fields = grid_configs['group_fields_to_sum'] || []
        avg_fields = grid_configs['group_fields_to_avg'] || []
        min_fields = grid_configs['group_fields_to_min'] || []
        max_fields = grid_configs['group_fields_to_max'] || []
        grouped_fields = grid_configs['group_fields'] || []
        grouped_fields = [] if !grid_configs['grouped']
        fields = hash['fields'] || {}

        rpt = Dataminer::Report.new(grid_configs['caption'] || 'Unknown report')
        rpt.sql = hash['query']
        rpt.ordered_columns.each do | column|
          if grid_configs['column_widths'] && grid_configs['column_widths'][column.name]
            rpt.column(column.name).width = grid_configs['column_widths'][column.name]
          end
          if grid_configs['data_types'] && grid_configs['data_types'][column.name]
            rpt.column(column.name).data_type = grid_configs['data_types'][column.name].to_sym
          end
          if grid_configs['column_captions'] && grid_configs['column_captions'][column.name]
            rpt.column(column.name).caption = grid_configs['column_captions'][column.name]
          end
          if groupable_fields.include?(column.name)
            rpt.column(column.name).groupable = true
          end
          if sum_fields.include?(column.name)
            rpt.column(column.name).group_sum = true
          end
          if avg_fields.include?(column.name)
            rpt.column(column.name).group_avg = true
          end
          if min_fields.include?(column.name)
            rpt.column(column.name).group_min = true
          end
          if max_fields.include?(column.name)
            rpt.column(column.name).group_max = true
          end
          if hidden.include?(column.name)
            rpt.column(column.name).hide = true
          end
          if grid_configs['formats'] && grid_configs['formats'][column.name]
            rpt.column(column.name).format = grid_configs['formats'][column.name].to_sym
          end
          rpt.column(column.name).group_by_seq = grouped_fields.index(column.name)
        end

        fields.each do |k,field_def|
          list_def = field_def['list']
          control_type = case field_def['field_type']
                         when 'lookup'
                           :list
                         when 'daterange'
                           :daterange
                         else
                           :text
                         end
          caption = field_def['caption']

          data_type = :string #...check column for other type????
          param_name = field_def['field_name']
          rpt.ordered_columns.each do | column|
            if column.namespaced_name == param_name
              data_type = column.data_type
            end
          end
          rpt.add_parameter_definition( Dataminer::QueryParameterDefinition.new(param_name,
                                                                  :caption       => caption,
                                                                  :data_type     => data_type,
                                                                  :control_type  => control_type,
                                                                  :ui_priority   => 1,
                                                                  :default_value => nil,
                                                                  :list_def      => list_def))
        end
        yp = Dataminer::YamlPersistor.new(File.join(path, name))
        rpt.save(yp)
        rpt
      end

      private
      attr_reader :path

    end

  end

end
