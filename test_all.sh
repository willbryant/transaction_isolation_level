#!/bin/sh

set -e

for version in 5.0.7.2 5.1.7 5.2.4.4 6.0.3.4 6.1.0.rc1
do
	RAILS_VERSION=$version bundle update activerecord
	RAILS_ENV=postgresql bundle exec rake
done
