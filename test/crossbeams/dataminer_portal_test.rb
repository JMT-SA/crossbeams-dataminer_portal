require 'test_helper'

class Crossbeams::DataminerPortalTest < DmPortalApp::Test

  def app
    Crossbeams::DataminerPortal::WebPortal
  end

  def test_that_it_has_a_version_number
    refute_nil ::Crossbeams::DataminerPortal::VERSION
  end

  def test_default_page
    get '/'
    assert last_response.ok?
    assert_match /DATAMINER REPORT INDEX/, last_response.body
    assert_match /Admin index/, last_response.body
  end

end
