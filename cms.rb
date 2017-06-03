require "sinatra"
require "sinatra/reloader"
require "tilt/erubis"

root = File.expand_path("..", __FILE__)

configure do
  enable :sessions
  set :session_secret, 'super secret'
end

get "/" do
  @files = Dir.glob(root + "/data/*").map do |path|
    File.basename(path)
  end
  erb :index
end

get "/:filename" do
  file_path = root + "/data/" + params[:filename]
  if File.exist?(file_path)
    headers["Content-Type"] = "text/plain"
    File.read(file_path)
  else
    session[:message] = "#{params[:filename]} does not exist."
    redirect "/"
  end
end
