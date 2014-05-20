require 'app/ui'
require 'sinatra'
require 'tilt'
require 'puppet'

use Rack::Session::Cookie, :secret => '4zENWx0ruhWU3ZN'
Puppet.initialize_settings_for_run_mode(:master)

run HieraBrowserUI
