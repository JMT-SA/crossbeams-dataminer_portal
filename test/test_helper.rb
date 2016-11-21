$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'crossbeams/dataminer_portal'
require 'crossbeams/dataminer_portal/application/app'

require 'rack/test'
require 'minitest/autorun'
# config/dm_defauls.yml.. - to connect to test db....

ENV['RACK_ENV'] = 'test'

module DmPortalApp
  class Test < Minitest::Test
    include Rack::Test::Methods
  end
end
