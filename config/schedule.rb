set :output, "#{ path }/log/sync.log"

# REVIEW: get times from Settings
#  require File.expand_path(File.join(File.dirname(__FILE__), '..', 'config', 'environment'))
#  require 'rubygems'
#  every Settings.channel.synch_every_minutes.minutes do

every 1.minute do
  rake 'sync:all'
end

# every 1.day, at: '5:00 am' do
#   rake '-s sitemap:refresh'
# end
