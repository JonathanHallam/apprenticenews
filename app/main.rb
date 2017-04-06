require 'sinatra/base'
require 'pg'
require 'gibberish'

class ApprenticeNews < Sinatra::Application

  enable :sessions

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
      conn.exec("INSERT INTO submissions (url, title, score) VALUES ('#{link}', '#{info}', 0)")
    end
  end

  def sign_up(first_name, surname, email, password)
    thing = Gibberish::HMAC256("#{surname}", "#{password}")
    db_connection do |conn|
      conn.exec("INSERT INTO users (email, firstname, surname, password) VALUES ('#{email}', '#{first_name}', '#{surname}', '#{thing}')")
    end
  end

  def get_name(email)
    db_connection do |conn|
      conn.exec("SELECT firstname FROM users WHERE email='#{email}'")
    end
  end

  def check_signin_data(email, password)
    thingy = db_connection do |conn|
      conn.exec("SELECT * FROM users WHERE email='#{email}'")
    end
    thingy.each do |stuff|
      @sur = stuff['surname']
      @passw = stuff['password']
    end
    thing = Gibberish::HMAC256("#{@sur}", "#{password}")
    thing == @passw
  end

  def vote(way, id)
    connection = db_connection do |conn|
      conn.exec("SELECT * FROM submissions WHERE id='#{id.to_i}'")
    end
    connection.each do |stuff|
      @score = stuff['score']
    end
    if way == "up"
      @score = (@score.to_i + 1)
    else
      @score = @score.to_i - 1
    end
    db_connection do |conn|
      conn.exec("UPDATE submissions SET score = '#{@score}' WHERE id='#{id.to_i}'")
    end
  end

  get '/' do
    @everything = everything
    erb :index, locals: { title: 'Apprentice News', wrong: ' '}
  end

  get '/submit' do
    erb :submit, locals: {  title: 'Submit'  }
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

  post '/create_account' do
    first_name = params[:first_name]
    surname = params[:surname]
    email = params[:email]
    password = params[:password]
    sign_up(first_name, surname, email, password)
    erb :created, locals: { title: 'Apprentice News' }
  end

  post '/' do
    @everything = everything
    @jeff = []
    params.each do |key, value|
      @jeff << key << value
    end
    democracy = params[:vote_button]
    email = params[:email]
    password = params[:password]
    if check_signin_data(email, password) == true
      @name = get_name(email)
      erb :login_home, locals: {title: 'Apprentice News', name: "#{@name}" }
    elsif democracy != ""
      @arr = democracy.split(' ')
      vote(@arr[0], @arr[1])
      erb :index, locals: {title: 'Apprentice News'}
    else
      erb :index, locals: { title: 'Apprentice News', wrong: "<div class='hello'>The E-mail/Password combination you entered is incorrect, please try again.</div>"}
    end

  end

  if app_file == $0
    run!
  end

end
