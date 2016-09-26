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

    class MySinatraApp < Sinatra::Application

      configure do
        enable :logging
        # mkdir log if it does not exist...
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

      get '/' do
        dataset = DB['select id from users']
        "GOT THERE... running with #{settings.appname} <a href='#{settings.url_prefix}test_page'>Go to test page</a><p>Users: #{dataset.count} with ids: #{dataset.map(:id).join(', ')}.</p><p>Random user: #{DB['select user_name FROM users LIMIT 1'].first[:user_name]}</p>"
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
