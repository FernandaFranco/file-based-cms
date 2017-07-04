require "sinatra"
require "sinatra/reloader"
require "tilt/erubis"
require "redcarpet"
require "yaml"
require "bcrypt"
require "date"

configure do
  enable :sessions
  set :session_secret, 'super secret'
end

VALID_IMG_EXTENSIONS = [".png", ".jpg"]

helpers do
  def image?(filename)
    VALID_IMG_EXTENSIONS.include?(File.extname(filename))
  end
end

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

def credentials_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/users.yml", __FILE__)
  else
    File.expand_path("../users.yml", __FILE__)
  end
end

def public_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/public", __FILE__)
  else
    File.expand_path("../public", __FILE__)
  end
end

def load_user_credentials
  YAML.load_file(credentials_path)
end

def update_user_credentials(credentials)
  File.open(credentials_path, 'w') do |file|
    file.write(Psych.dump(credentials))
  end
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

def valid_signup_credentials?(username, password)
  credentials = load_user_credentials

  if credentials.key?(username) || username.empty? || password.empty?
    false
  else
    bcrypt_password = BCrypt::Password.create(password).to_s
    credentials[username] = bcrypt_password
    update_user_credentials(credentials)
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
  when *VALID_IMG_EXTENSIONS
    headers["Content-Type"] = "image/jpeg"
    content
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
                            .reject { |file| File.basename(file).match?(/\(\S+\)\S+\.\w+/)}
  erb :index
end

get "/new" do
  redirect_not_signed_in_user

  erb :new
end

get "/new_image" do
  redirect_not_signed_in_user

  erb :new_image
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

def create_datestamp_copy(name, content)
  stamped_name = "(" + DateTime.now.to_s + ")" + File.basename(name, ".*") +  File.extname(name)
  File.open(File.join(data_path, stamped_name), "w") do |file|
    file.write(content)
  end
end

def create_document(name, content = "")
  File.open(File.join(data_path, name), "w") do |file|
    file.write(content)
  end

  create_datestamp_copy(name, content)
end

def upload_image(name, content)
  File.open(File.join(data_path, name), "w") do |file|
    file.write(content.read)
  end
end

post "/new" do
  redirect_not_signed_in_user

  filename = params[:new_document].to_s
  file_path = File.join(data_path, filename)
  if filename.size.zero?
    session[:message] = "A name is required."
    status 422
    erb :new
  elsif File.extname(filename) == "" || ![".md", ".txt"].include?(File.extname(filename))
    session[:message] = "Invalid extension name. Valid extensions are .txt, .md"
    status 422
    erb :new
  elsif File.exist?(file_path)
    session[:message] = "Document name already in use."
    status 422
    erb :new
  elsif filename.include?("(") || filename.include?(")")
    session[:message] = "Name cannot contain parentheses."
    status 422
    erb :new
  else
    create_document(filename)
    session[:message] = "#{filename} was created."
    redirect "/"
  end
end

post "/new_image" do
  redirect_not_signed_in_user

  filename = params[:new_image][:filename].to_s
  content = params[:new_image][:tempfile]
  file_path = File.join(data_path, filename)
  if filename.size.zero?
    session[:message] = "An image is required."
    status 422
    erb :new_image
  elsif File.extname(filename) == "" || !VALID_IMG_EXTENSIONS.include?(File.extname(filename))
    session[:message] = "Invalid extension name. Valid extensions are #{VALID_IMG_EXTENSIONS.join(', ')}"
    status 422
    erb :new_image
  elsif File.exist?(file_path)
    session[:message] = "Image name already in use."
    status 422
    erb :new_image
  elsif filename.include?("(") || filename.include?(")")
    session[:message] = "Name cannot contain parentheses."
    status 422
    erb :new
  else
    upload_image(filename, content)
    session[:message] = "#{filename} was uploaded."
    redirect "/"
  end
end

post "/:filename" do
  redirect_not_signed_in_user

  new_content = params[:new_content]
  filename = params[:filename]
  file_path = File.join(data_path, filename)
  File.write(file_path, new_content)

  stamped_filename = "(" + DateTime.now.to_s + ")" + File.basename(filename, ".*") + File.extname(filename)
  file_path = File.join(data_path, stamped_filename)
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

def duplicated_filename(original_filename)
  number = 1
  duplicated_filename = File.basename(original_filename, ".*") + "_" + number.to_s + File.extname(original_filename)
  duplicated_file_path = File.join(data_path, duplicated_filename)

  while File.exist?(duplicated_file_path)
    number += 1
    duplicated_filename = File.basename(original_filename, ".*") + "_" + number.to_s + File.extname(original_filename)
    duplicated_file_path = File.join(data_path, duplicated_filename)
  end

  duplicated_filename
end

post "/:filename/duplicate" do
  redirect_not_signed_in_user

  filename = params[:filename].to_s
  file_path = File.join(data_path, filename)
  content = File.read(file_path)
  create_document(duplicated_filename(filename), content)
  session[:message] = "#{filename} has been duplicated."
  redirect "/"
end

get "/:filename/previous" do
  redirect_not_signed_in_user

  @filename= params[:filename].to_s
  regex = /\(\S+\)#{@filename}/

  pattern = File.join(data_path, "*")
  @files = Dir.glob(pattern).map { |path| File.basename(path) }
                            .select { |file| file.match?(regex) }

  erb :previous
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
    session[:message] = "Invalid username and/or password."
    status 422
    erb :signin
  end
end

post "/users/signout" do
  session.delete(:username)
  session[:message] = "You have been signed out."
  redirect "/"
end

get "/users/signup" do
  erb :signup
end

post "/users/signup" do
  username = params[:username]

  if valid_signup_credentials?(username, params[:password])
    session[:username] = username
    session[:message] = "Welcome!"
    redirect "/"
  else
    session[:message] = "Invalid username and/or password."
    status 422
    erb :signup
  end
end
