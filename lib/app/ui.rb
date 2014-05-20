require 'hiera_browser'
require 'ap'
require 'json'
require 'slim'
require 'cuba'

class HieraBrowserUI < Cuba
  def slim(template)
    Slim::Template.new("lib/app/views/#{template.to_s}.slim").render(self)
  end

  def back
    req.referer
  end
end

HieraBrowserUI.define do
  on get do 
    # human ui
    on root do
      res.redirect('/nodes')
    end

    on 'nodes' do
      @title = "node list"
      @nodes = Node.list
      res.write slim :nodes
    end

    on 'node/:node' do |node|
      @title, @node = "node: #{node}", node
      keys = session[:keys] || []
      @values = Node.new(:certname => node).sorted_values(:keys => keys)
      res.write slim :node
    end

    on 'add/additive/:key' do |key|
      session[:keys] = session[:keys] || []
      session[:keys] << key
      res.redirect back
    end

    on 'remove/additive/:key' do |key|
      session[:keys].reject!{|k| k == key}
      res.redirect back
    end

    on 'debug/session' do
      res.write JSON.generate(session[:keys])
    end

    # api
    on 'api/v1' do
      on 'nodes' do
        @nodes = Node.list
        res.write JSON.generate(@nodes)
      end

      on "node/:node" do |node|
        keys = session[:keys] || []
        @values = Node.new(:certname => node).sorted_values(:keys => keys)
        res.write JSON.generate(@values)
      end
    end
  end

  on post do
    on "api/v1" do
      on "node/:node" do |node|
        keys = JSON.instance_eval(request['keys']) || []
        @values = Node.new(:certname => node).sorted_values(:keys => keys)
        res.write JSON.generate(@values)
      end
    end
  end
end
