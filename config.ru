require 'app/ui'
require 'rack/protection'

HieraBrowserUI.use Rack::Session::Cookie, :secret => '4zENWx0ruhWU3ZN'
HieraBrowserUI.use Rack::Protection

run HieraBrowserUI
