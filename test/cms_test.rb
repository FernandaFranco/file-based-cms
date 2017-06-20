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
    hashed_password = BCrypt::Password.create("secret").to_s
    File.open(credentials_path, 'w') do |file|
      file.write(Psych.dump({ "admin" => hashed_password }))
    end
  end

  def teardown
    FileUtils.rm_rf(data_path)
    File.delete(credentials_path)
  end

  def session
    last_request.env["rack.session"]
  end

  def admin_session
    { "rack.session" => { username: "admin" } }
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
1995 - Ruby 0.95 released."

    get "/history.txt"
    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_includes last_response.body, "1993 - Yukihiro Matsumoto dreams up"
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

  def test_editing_document
    create_document "changes.txt"
    get "/changes.txt/edit", {}, admin_session

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "<textarea"
    assert_includes last_response.body, '<button type="submit"'
  end

  def test_editing_document_signed_out
    create_document "changes.txt"

    get "/changes.txt/edit"

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_updating_document
    post "/changes.txt", { new_content: "new content" }, admin_session
    assert_equal 302, last_response.status
    assert_equal "changes.txt has been updated.", session[:message]

    # get last_response["Location"]
    # assert_includes last_response.body, "changes.txt has been updated"

    get "/changes.txt"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "new content"
  end

  def test_updating_document_signed_out
    post "/changes.txt", new_content: "new content"
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_view_new_document_form
    get "/new", {}, admin_session
    assert_equal 200, last_response.status
    assert_includes last_response.body, "<input"
    assert_includes last_response.body, '<button type="submit"'
  end

  def test_view_new_document_form_signed_out
    get "/new"
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_creating_new_documents
    post "/new", { new_document: "text.txt" }, admin_session
    assert_equal 302, last_response.status
    assert_equal "text.txt was created.", session[:message]

    # get last_response["Location"]
    # assert_includes last_response.body, "text.txt was created"

    get "/"
    assert_includes last_response.body, "text.txt"
  end

  def test_creating_new_documents_signed_out
    post "/new", new_document: "text.txt"
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_creating_new_document_without_filename
    post "/new", { new_document: "" }, admin_session
    assert_equal 422, last_response.status
    assert_includes last_response.body, "A name is required."
  end

  def test_creating_new_document_with_wrong_extension
    post "/new", { new_document: "test.exe" }, admin_session
    assert_equal 422, last_response.status
    assert_includes last_response.body, "Invalid extension name."
  end

  def test_creating_new_document_existing_name
    create_document("test.txt")
    post "/new", { new_document: "test.txt" }, admin_session
    assert_equal 422, last_response.status
    assert_includes last_response.body, "Document name already in use."
  end

  def test_deleting_documents
    create_document("changes.txt")

    get "/"
    assert_includes last_response.body, '<button type="submit"'

    post "/changes.txt/delete", {}, admin_session
    assert_equal 302, last_response.status
    assert_equal "changes.txt has been deleted.", session[:message]

    # get last_response["Location"]
    # assert_includes last_response.body, "changes.txt has been deleted."

    get "/"
    refute_includes last_response.body, 'href="/changes.txt"'
  end

  def test_deleting_documents_signed_out
    create_document("changes.txt")

    post "/changes.txt/delete"
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_duplicating_documents
    create_document("changes.txt")

    post "/changes.txt/duplicate", {}, admin_session
    assert_equal 302, last_response.status
    assert_equal "changes.txt has been duplicated.", session[:message]

    get last_response["Location"]
    assert_includes last_response.body, "changes_1.txt"
  end

  def test_duplicating_documents_signed_out
    create_document("changes.txt")

    post "/changes.txt/duplicate"
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_signing_in
    get "/"

    assert_includes last_response.body, "Sign In"

    get "/users/signin"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<input"
    assert_includes last_response.body, '<button type="submit"'
  end

  def test_valid_credentials
    post "/users/signin", username: "admin", password: "secret"
    assert_equal 302, last_response.status
    assert_equal "admin", session[:username]

    get last_response["Location"]
    assert_equal 200, last_response.status
    assert_includes last_response.body, "Signed in as admin"
  end

  def test_invalid_credentials
    post "/users/signin", username: "admin", password: "wrong"
    assert_equal 422, last_response.status
    assert_nil session[:username]
    assert_includes last_response.body, "Invalid Credentials"
  end

  def test_signing_up
    get "/"

    assert_includes last_response.body, "Sign Up"

    get "/users/signup"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<input"
    assert_includes last_response.body, '<button type="submit"'
  end

  def test_valid_signup_credentials
    post "/users/signup", username: "fernanda", password: "supersecret"
    assert_equal 302, last_response.status
    assert_equal "fernanda", session[:username]

    get last_response["Location"]
    assert_equal 200, last_response.status
    assert_includes last_response.body, "Signed in as fernanda"
  end

  def test_invalid_signup_credentials
    post "/users/signup", username: "", password: "secret"
    assert_equal 422, last_response.status
    assert_nil session[:username]
    assert_includes last_response.body, "Invalid username and/or password."
  end

  def test_signout
    get "/", {}, "rack.session" => { username: "admin" }
    assert_includes last_response.body, "Signed in as admin"
    # post "/users/signin", username: "admin", password: "secret"
    # get last_response["Location"]

    post "/users/signout"
    get last_response["Location"]

    assert_nil session[:username]
    assert_includes last_response.body, "You have been signed out."
    assert_includes last_response.body, "Sign In"
  end
end
