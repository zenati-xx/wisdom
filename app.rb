require 'rubygems'
require 'haml'
require 'sinatra'
require 'data_mapper'
require 'dm-postgres-adapter'
#require 'dm-sqlite-adapter'

enable :sessions
DataMapper.setup(:default, 'postgres://vurfuwjgak:G9GxPgnXqkSYXUBJkF6e@ec2-50-16-226-121.compute-1.amazonaws.com/vurfuwjgak')
#DataMapper.setup(:default, ENV['DATABASE_URL'] || "sqlite3://#{Dir.pwd}/db.db") #testing with sqlite locally, comment before deploying

configure do
  set :site_title, 'Wisdom'
  set :site_description, 'Here description'
  set :site_author, 'Yassine'
  
  set :site_username, 'Username'
  set :site_password, 'Password'
  
  set :posts_per_page, 10
end

class Post
  include DataMapper::Resource
  
  property :id, Serial
  property :title, String
  property :content, Text
  property :created_at, DateTime
  property :slug, Text
  property :publish, Boolean, :default => true
  
  has n, :tags
  
  def full_url
    "/#{created_at.year}/#{created_at.month}/#{created_at.day}/#{slug}"
  end
  
end

class Page
  include DataMapper::Resource
  
  property :id, Serial
  property :title, String
  property :content, Text
  property :created_at, DateTime
  property :slug, Text
  property :publish, Boolean, :default => true
end

class Tag
  include DataMapper::Resource
  
  property :id, Serial
  property :content, String
  property :slug, String
  
  belongs_to :post
end

DataMapper.finalize
DataMapper.auto_upgrade!

helpers do
  include Rack::Utils
  alias_method :h, :escape_html
end

not_found do
  redirect '/'
end

def auth
  session[:bazinga]
end

def month(month)
  case month
    when 1
      return 'January'
  end
end

def make_slug(title)
  return title.downcase.gsub(/ /, '_').gsub(/[^a-z0-9_]/, '').squeeze('_')
end

before do
  @pages = Page.all(:publish => true) if !auth
  @pages = Page.all if auth
end

get '/' do
  @posts = Post.all(:publish => true, :order => [:created_at.desc]).first(settings.posts_per_page) if !auth
  @posts = Post.all(:order => [:created_at.desc]).first(settings.posts_per_page) if auth
  haml :index, :format => :html5
end

get '/feed' do
  @posts = Post.all(:publish => true, :order => [:created_at.desc]).first(settings.posts_per_page)
  builder :feed
end

get '/login' do
  redirect '/' if auth
  haml :login, :format => :html5
end

post '/login' do
  redirect '/' if auth
  redirect '/login' if settings.site_username != params[:username] or settings.site_password != params[:password]
  
  session[:bazinga] = true
  redirect '/'
end

get '/logout' do
  session[:bazinga] = false
  redirect '/'
end

get '/:year/:month/:day/:slug' do
  @post = Post.first(:slug => params[:slug], :publish => true) if !auth
  @post = Post.first(:slug => params[:slug]) if auth
  
  redirect '/' if !@post
  haml :post_show, :format => :html5
end

get '/post/new' do
  redirect '/login' if !auth
  haml :post_new, :format => :html5
end

post '/post/new' do
  redirect '/login' if !auth
  
  redirect '/post/new' if params[:content] == '<br>'
  title = params[:title].empty? ? 'Untitled post' : params[:title]
  
  post = Post.create(
    :title => title,
    :content => params[:content],
    :created_at => Time.now,
    :slug => make_slug(title),
    :publish => params[:publish].nil? ? true : false
  )
  
  if !params[:tags].empty?
    params[:tags].split(', ').each do |tag|
      post.tags << Tag.create(:content => tag, :slug => make_slug(tag))
    end
    
    post.save
  end
   
  redirect post.full_url
end

get '/post/edit/:id' do |id|
  redirect '/login' if !auth
  @post = Post.first(:id => id)
  haml :post_edit, :format => :html5
end

post '/post/edit/:id' do |id|
  redirect '/login' if !auth
  post = Post.first(:id => id)
  
  redirect "/post/edit/#{id}}" if params[:content] == '<br>'
  title = params[:title].empty? ? 'Untitled post' : params[:title]
  
  post.update(
    :title => title,
    :content => params[:content],
    :slug => make_slug(title),
  )
  
  post.tags.all.destroy
  
  if !params[:tags].empty?
    params[:tags].split(', ').each do |tag|
      post.tags << Tag.create(:content => tag, :slug => make_slug(tag))
    end
    
    post.save
  end
  
  redirect post.full_url
end

get '/post/publish/:id' do |id|
  redirect '/login' if !auth
  post = Post.first(:id => id)
  post.update(:publish => true)
  
  redirect post.full_url
end

get '/post/unpublish/:id' do |id|
  redirect '/login' if !auth
  post = Post.first(:id => id)
  post.update(:publish => false)
  
  redirect post.full_url
end

get '/post/delete/:id' do |id|
  redirect '/login' if !auth
  Post.first(:id => id).tags.all.destroy
  Post.first(:id => id).destroy
  redirect '/'
end

get '/page/new' do
  redirect '/' if !auth
  haml :page_new, :format => :html5
end

get '/page/:slug' do |slug|
  @page = Page.first(:slug => params[:slug], :publish => true) if !auth
  @page = Page.first(:slug => params[:slug]) if auth
  
  redirect '/' if !@page
  haml :page_show, :format => :html5
end

post '/page/new' do
  redirect '/login' if !auth
  
  redirect '/page/new' if params[:content] == '<br>'
  #check_slug = Page.all(:slug => make_slug(params[:title]))
  title = params[:title].empty? ? 'Untitled page' : params[:title]
  
  page = Page.create(
    :title => title,
    :content => params[:content],
    :created_at => Time.now,
    :slug => make_slug(title),
    :publish => params[:publish].nil? ? true : false
  )
   
  redirect "/page/#{page.slug}"
end

get '/page/edit/:id' do |id|
  redirect '/login' if !auth
  @page = Page.first(:id => id)
  haml :page_edit, :format => :html5
end

post '/page/edit/:id' do |id|
  redirect '/login' if !auth
  page = Page.first(:id => id)
  
  redirect "/page/edit/#{id}" if params[:content] == '<br>'
  title = params[:title].empty? ? 'Untitled page' : params[:title]
  
  page.update(
    :title => title,
    :content => params[:content],
    :slug => make_slug(title),
  )
  
  redirect "/page/#{page.slug}"
end

get '/page/publish/:id' do |id|
  redirect '/login' if !auth
  page = Page.first(:id => id)
  page.update(:publish => true)
  
  redirect "/page/#{page.slug}"
end

get '/page/unpublish/:id' do |id|
  redirect '/login' if !auth
  page = Page.first(:id => id)
  page.update(:publish => false)
  
  redirect "/page/#{page.slug}"
end

get '/page/delete/:id' do |id|
  redirect '/login' if !auth
  Page.first(:id => id).destroy
  redirect '/'
end

get '/draft' do
  redirect '/login' if !auth
  
  @posts = Post.all(:publish => false, :order => [:created_at.desc])
  haml :draft, :format => :html5
end

get '/tag/:tag' do |tag|
  @tag = tag
  @posts = Post.all(:publish => true, :order => [:created_at.desc], :tags => {:slug => make_slug(tag)}) if !auth
  @posts = Post.all(:order => [:created_at.desc], :tags => {:slug => make_slug(tag)}) if auth
  haml :tag_show, :format => :html5
end

get '/archive' do
  @posts = Post.all(:publish => true, :order => [:created_at.desc]) if !auth
  @posts = Post.all(:order => [:created_at.desc]) if auth
  
  haml :archive, :format => :html5
end
