require "sinatra"
require "sinatra/reloader"
require "tilt/erubis"
require "redcarpet"

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

get "/" do
  pattern = File.join(data_path, "*")
  @files = Dir.glob(pattern).map do |path|
    File.basename(path)
  end
  erb :index
end

get "/new" do
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
  filename = params[:new_document].to_s
  if filename.size == 0
    session[:message] = "A name is required."
    status 422
    erb :new
  elsif File.extname(filename) == "" || ![".md", ".txt"].include?(File.extname(filename))
    session[:message] = "Invalid extension name."
    status 422
    erb :new
  else
    create_document(filename)
    session[:message] = "#{filename} was created."
    redirect "/"
  end
end

post "/:filename" do
  new_content = params[:new_content]
  filename = params[:filename]
  file_path = File.join(data_path, filename)
  File.write(file_path, new_content)
  session[:message] = "#{filename} has been updated."
  redirect "/"
end
