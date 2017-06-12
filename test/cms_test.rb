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

  def setup
    FileUtils.mkdir_p(data_path)
  end

  def session
    last_request.env["rack.session"]
  end

  def create_document(name, content = "")
    File.open(File.join(data_path, name), "w") do |file|
      file.write(content)
    end
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
    assert_equal "notafile.ext does not exist.", session[:message]

    # get last_response["Location"]
    # assert_includes last_response.body, "notafile.ext does not exist."
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
    post "/changes.txt", new_content: "new content"
    assert_equal 302, last_response.status
    assert_equal "changes.txt has been updated.", session[:message]

    # get last_response["Location"]
    # assert_includes last_response.body, "changes.txt has been updated"

    get "/changes.txt"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "new content"
  end

  def test_view_new_document_form
    get "/new"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "<input"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_creating_new_documents
    post "/new", new_document: "text.txt"
    assert_equal 302, last_response.status
    assert_equal "text.txt was created.", session[:message]

    # get last_response["Location"]
    # assert_includes last_response.body, "text.txt was created"

    get "/"
    assert_includes last_response.body, "text.txt"
  end

  def test_creating_new_document_without_filename
    post "/new", new_document: ""
    assert_equal 422, last_response.status
    assert_includes last_response.body, "A name is required."
  end

  def test_deleting_documents
    create_document("changes.txt")

    get "/"
    assert_includes last_response.body, %q(<button type="submit")

    post "/changes.txt/delete"
    assert_equal 302, last_response.status
    assert_equal "changes.txt has been deleted.", session[:message]

    # get last_response["Location"]
    # assert_includes last_response.body, "changes.txt has been deleted."

    get "/"
    refute_includes last_response.body, %q(href="/changes.txt")
  end

  def test_signing_in
    get "/"

    assert_includes last_response.body, "Sign In"

    get "/users/signin"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<input"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_valid_credentials
    post "/users/signin", username: "admin", password: "secret"
    assert_equal 302, last_response.status
    assert_equal "Welcome!", session[:message]
    assert_equal "admin", session[:username]

    get last_response["Location"]
    assert_equal 200, last_response.status
    # assert_includes last_response.body, "Welcome!"
    assert_includes last_response.body, "Signed in as admin"
  end

  def test_invalid_credentials
    post "/users/signin", username: "admin", password: "wrong"
    assert_equal 422, last_response.status
    assert_nil session[:username]
    assert_includes last_response.body, "Invalid Credentials"
  end

  def test_signout
    get "/", {}, {"rack.session" => {username: "admin"}}
    assert_includes last_response.body, "Signed in as admin"
    # post "/users/signin", username: "admin", password: "secret"
    # get last_response["Location"]

    post "/users/signout"
    get last_response["Location"]

      assert_nil session[:username]
      assert_includes last_response.body, "You have been signed out."
      assert_includes last_response.body, "Sign In"
  end

  def teardown
    FileUtils.rm_rf(data_path)
  end
end
