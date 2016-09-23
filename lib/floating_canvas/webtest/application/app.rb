require 'sinatra'

module FloatingCanvas
  module Webtest

    class MySinatraApp < Sinatra::Application
      get '/' do
        "GOT THERE..."
      end
    end
  end
end
