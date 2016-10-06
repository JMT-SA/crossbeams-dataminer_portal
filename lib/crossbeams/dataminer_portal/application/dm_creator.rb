module Crossbeams
  module DataminerPortal

    class DmCreator
      attr_reader :report, :db

      def initialize(db, report)
        @db     = db
        @report = report
      end

      def modify_column_dtattypes
        lkp_types = column_datatypes
        report.columns.each do |name, column|
          data_type = lkp_types[name]
          next if data_type.nil?

          report.columns[name].data_type = data_type
          case data_type
          when :boolean
            report.columns[name].groupable = true
          when :string
            report.columns[name].groupable = true
          when :integer
            unless name.end_with?('_id')
              report.columns[name].group_sum = true
            end
          when :number
            report.columns[name].group_sum = true
            report.columns[name].format    = :delimited_1000
          end
          puts "#{name} : #{data_type} - #{data_type.class.name}"
        end
        report
      end

      private

      def column_datatypes
        tables    = report.tables
        column_types = {}
        tables.each do |table|
          db.schema(table.sub('public.', '')).each do |col| # NB problem if another schema used...
            type = col[1][:type]
            column_types[col.first.to_s] = case type # translate into :number etc...
                                           when :decimal, :float
                                             :number
                                           else
                                             type
                                           end
            # Check types with DB.schema('parties_roles').map {|c| c[1][:type] }.compact.uniq.sort
            # :boolean, :date, :datetime, :decimal, :float, :integer, :string
          end
        end
        column_types
      end

    end

  end

end
