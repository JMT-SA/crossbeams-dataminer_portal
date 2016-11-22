#TODO:- Use filenames instead of ids as keys.
#      - Change this to just handle routes and pass the coding on to external objects.
#      - code reloading
require 'sinatra/base'
require 'sinatra/contrib'
require 'sequel'
require 'rack-flash'
require_relative './admin'
require_relative './report'
require_relative './helpers'

module Crossbeams
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

    class WebPortal < Sinatra::Base
      register Sinatra::Contrib
      register Crossbeams::DataminerPortal::Admin
      register Crossbeams::DataminerPortal::Report
       helpers Sinatra::DataminerPortalHelpers

      configure do
        enable :logging
        # mkdir log if it does not exist...
        Dir.mkdir('log') unless Dir.exist?('log')
        file = File.new("log/dm_#{settings.environment}.log", 'a+')
        file.sync = true
        use Rack::CommonLogger, file

        enable :sessions
        use Rack::Flash, :sweep => true

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
      Crossbeams::DataminerPortal::DB = Sequel.postgres(settings.database['name'], :user => settings.database['user'], :password => settings.database['password'], :host => settings.database['host'] || 'localhost')


      # helpers do
      # end


      get '/' do
        erb "<a href='/#{settings.url_prefix}index'>DATAMINER REPORT INDEX</a> | <a href='/#{settings.url_prefix}admin'>Admin index</a>"
      end

      get '/index' do
        # TODO: sort report list, group, add tags etc...

        rpt_list = DmReportLister.new(settings.dm_reports_location).get_report_list(persist: true)

        erb(<<-EOS)
        <h1>Dataminer Reports</h1>
        <ol><li>#{rpt_list.map {|r| "<a href='/#{settings.url_prefix}report/#{r[:id]}'>#{r[:caption]}</a>" }.join('</li><li>')}</li></ol>
        <p><a href='/#{settings.url_prefix}admin'>Admin index</a></p>
        EOS
      end

    end

  end

end
# Could we have two dm's connected to different databases?
# ...and store each set of yml files in different dirs.
# --- how to use the same gem twice on diferent routes?????
#
