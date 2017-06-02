ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "rack/test"

require_relative "../cms"

class CMSTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def test_index
    get "/"
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "about.txt"
    assert_includes last_response.body, "changes.txt"
    assert_includes last_response.body, "history.txt"
  end

  def test_viewing_text_document
    get "/history.txt"
    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_includes last_response.body, "1993 - Yukihiro Matsumoto dreams up Ruby.
1995 - Ruby 0.95 released.
1996 - Ruby 1.0 released.
1998 - Ruby 1.2 released.
1999 - Ruby 1.4 released.
2000 - Ruby 1.6 released.
2003 - Ruby 1.8 released.
2007 - Ruby 1.9 released.
2013 - Ruby 2.0 released.
2013 - Ruby 2.1 released.
2014 - Ruby 2.2 released.
2015 - Ruby 2.3 released."
  end
end
