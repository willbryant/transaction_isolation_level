require 'test/unit'
require 'rubygems'
require 'bundler'
Bundler.require(:default, :development)

RAILS_ENV = ENV['RAILS_ENV'] || 'postgresql'

database_config = YAML::load(IO.read(File.join(File.dirname(__FILE__), '/database.yml')))
ActiveRecord::Base.establish_connection(database_config[RAILS_ENV])
