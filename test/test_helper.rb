require 'test/unit'
require 'rubygems'
require 'bundler'
Bundler.require(:default, :development)

raise "use RAILS_ENV=mysql, RAILS_ENV=mysql2, or RAILS_ENV=postgresql to test this plugin" unless %w(mysql mysql2 postgresql).include?(ENV['RAILS_ENV'])
RAILS_ENV = ENV['RAILS_ENV']

database_config = YAML::load(IO.read(File.join(File.dirname(__FILE__), '/database.yml')))
ActiveRecord::Base.establish_connection(database_config[ENV['RAILS_ENV']])
