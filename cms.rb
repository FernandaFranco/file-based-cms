require "sinatra"
require "sinatra/reloader"
require "tilt/erubis"
require "redcarpet"
require "yaml"
require "bcrypt"

configure do
  enable :sessions
  set :session_secret, 'super secret'
end

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

def load_user_credentials
  credentials_path = if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/users.yml", __FILE__)
  else
    File.expand_path("../users.yml", __FILE__)
  end
  YAML.load_file(credentials_path)
end

def valid_credentials?(username, password)
  credentials = load_user_credentials

  if credentials.key?(username)
    bcrypt_password = BCrypt::Password.new(credentials[username])
    bcrypt_password == password
  else
    false
  end
end

def render_markdown(text)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(text)
end

def load_file_content(path)
  content = File.read(path)
  case File.extname(path)
  when ".txt"
    headers["Content-Type"] = "text/plain"
    content
  when ".md"
    render_markdown(content)
  end
end

def user_signed_in?
  session.key?(:username)
end

def redirect_not_signed_in_user
  unless user_signed_in?
    session[:message] = "You must be signed in to do that."
    redirect "/"
  end
end

get "/" do
  pattern = File.join(data_path, "*")
  @files = Dir.glob(pattern).map { |path| File.basename(path) }
  erb :index
end

get "/new" do
  redirect_not_signed_in_user

  erb :new
end

get "/:filename" do
  filename = params[:filename]
  file_path = File.join(data_path, filename)

  if File.exist?(file_path)
    load_file_content(file_path)
  else
    session[:message] = "#{filename} does not exist."
    redirect "/"
  end
end

get "/:filename/edit" do
  redirect_not_signed_in_user
  @filename = params[:filename]
  file_path = File.join(data_path, @filename)
  @content = File.read(file_path)
  erb :edit
end

def create_document(name, content = "")
  File.open(File.join(data_path, name), "w") do |file|
    file.write(content)
  end
end

post "/new" do
  redirect_not_signed_in_user

  filename = params[:new_document].to_s
  file_path = File.join(data_path, filename)
  if filename.size == 0
    session[:message] = "A name is required."
    status 422
    erb :new
  elsif File.extname(filename) == "" || ![".md", ".txt"].include?(File.extname(filename))
    session[:message] = "Invalid extension name."
    status 422
    erb :new
  elsif File.exist?(file_path)
    session[:message] = "Document name already in use."
    status 422
    erb :new
  else
    create_document(filename)
    session[:message] = "#{filename} was created."
    redirect "/"
  end
end

post "/:filename" do
  redirect_not_signed_in_user

  new_content = params[:new_content]
  filename = params[:filename]
  file_path = File.join(data_path, filename)
  File.write(file_path, new_content)
  session[:message] = "#{filename} has been updated."
  redirect "/"
end

post "/:filename/delete" do
  redirect_not_signed_in_user

  filename = params[:filename]
  file_path = File.join(data_path, filename)
  File.delete(file_path)
  session[:message] = "#{filename} has been deleted."
  redirect "/"
end

get "/users/signin" do
  erb :signin
end

post "/users/signin" do
  username = params[:username]

  if valid_credentials?(username, params[:password])
    session[:username] = username
    session[:message] = "Welcome!"
    redirect "/"
  else
    session[:message] = "Invalid Credentials"
    status 422
    erb :signin
  end
end

post "/users/signout" do
  session.delete(:username)
  session[:message] = "You have been signed out."
  redirect "/"
end
