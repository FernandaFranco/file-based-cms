ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "minitest/reporters"
require "rack/test"
require "fileutils"

require_relative "../cms"

Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new

class CMSTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def create_document(name, content = "")
    File.open(File.join(data_path, name), "w") do |file|
      file.write(content)
    end
  end

  def setup
    FileUtils.mkdir_p(data_path)
  end

  def test_index
    create_document "about.md"
    create_document "changes.txt"
    get "/"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "about.md"
    assert_includes last_response.body, "changes.txt"
  end

  def test_viewing_text_document
    create_document "history.txt", "1993 - Yukihiro Matsumoto dreams up Ruby.
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

  def test_nonexistent_document
    get "/notafile.ext"

    assert_equal 302, last_response.status

    get last_response["Location"]

    assert_includes last_response.body, "notafile.ext does not exist."
  end

  def test_viewing_markdown_document
    create_document "about.md", "# Ruby is..."
    get "/about.md"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "<h1>Ruby is...</h1>"
  end

  def test_editing_document_content
    create_document "changes.txt"
    get "/changes.txt/edit"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "<textarea"
    assert_includes last_response.body, %q(<button type="submit")
end

def test_updating_document
    post "/changes.txt", new_content: "anxianx"
    assert_equal 302, last_response.status

    get last_response["Location"]
    assert_includes last_response.body, "changes.txt has been updated"

    get "/changes.txt"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "anxianx"
  end

  def test_creating_new_documents

  end

  def teardown
    FileUtils.rm_rf(data_path)
  end
end
