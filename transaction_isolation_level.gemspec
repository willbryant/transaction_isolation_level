# -*- encoding: utf-8 -*-
require File.expand_path('../lib/transaction_isolation_level/version', __FILE__)

spec = Gem::Specification.new do |gem|
  gem.name         = 'transaction_isolation_level'
  gem.version      = TransactionIsolationLevel::VERSION
  gem.summary      = "Adds :isolation_level option to ActiveRecord #transaction calls"
  gem.description  = "Adds :isolation_level option to ActiveRecord #transaction calls, as well as :minimum_isolation_level.  Supports mysql and postgresql."
  gem.has_rdoc     = false
  gem.author       = "Will Bryant"
  gem.email        = "will.bryant@gmail.com"
  gem.homepage     = "http://github.com/willbryant/transaction_isolation_level"
  
  gem.executables  = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.files        = `git ls-files`.split("\n")
  gem.test_files   = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.require_path = "lib"
  
  gem.add_dependency "activerecord"
  gem.add_development_dependency "rake"
end
