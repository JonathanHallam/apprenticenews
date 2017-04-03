require 'sinatra/base'
require 'pg'

class ApprenticeNews < Sinatra::Application

  configure :development do
    set :database_config, { dbname: 'apprenticenews' }
  end

  configure :production do
    set :database_config, production_database_config
  end

  def db_connection
    begin
      connection = PG.connect(settings.database_config)
      yield(connection)
    ensure
      connection.close
    end
  end

  def everything
    db_connection do |conn|
      conn.exec('SELECT * FROM submissions ORDER BY id DESC')
    end
  end

  def submit(link, info)
    db_connection do |conn|
      conn.exec("INSERT INTO submissions (url, title) VALUES ('#{link}', '#{info}')")
    end
  end

  get '/' do
    @everything = everything
    erb :index, locals: { title: 'Apprentice News' }
  end

  get '/submit' do
    erb :submit, locals: {  title: 'Submit'
                            }
  end

  get '/create_account' do
    erb :create, locals: { title: 'Create Account' }
  end

  post '/submit' do
    link = params[:link]
    info = params[:info]
    submit(link, info)
    erb :submitted, :locals => {'link' => link, 'info' => info}
  end

  if app_file == $0
    run!
  end

end
