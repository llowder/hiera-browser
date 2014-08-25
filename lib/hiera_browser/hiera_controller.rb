require 'yaml'

# HieraController gives us a reasonably limited interface for Hiera
#
# @author David Gwilliam
class HieraController
  attr_reader :hiera_yaml

  # @param args [{:hiera_yaml => String}] path to `hiera.yaml`
  # @return [void]
  def initialize(args={})
    @hiera_yaml = args[:hiera_yaml] || ENV['HIERA_YAML']
    @hiera      = hiera
  end

  # @param args [Hash] arguments to pass to Hiera.new()
  # @return [Hiera]
  def hiera(args={})
    if @hiera
      @hiera
    else
      config = YAML.load_file(@hiera_yaml)
      config.merge!(:logger => 'flannel')
      Hiera.new(:config => config)
    end
  end

  # @return [Hash]
  def config
    hiera.config
  end

  # @return [Array]
  def datadirs
    config[:backends].map{|b| 
      path = config[b.to_sym][:datadir]
      DataDir.new(
        :hiera => self,
        :path  => path,
      )
    }
  end

  # @return [Array]
  def keys
    datadirs.map{|d| d.keys}.flatten.uniq.sort
  end

  # @return [Array]
  def hierarchy
    config[:hierarchy]
  end

  def hierarchy_variables
    hierarchy.map{|datasource|
      begin
        datasource.match(/\%\{([\:a-z_]+)\}/)[1]
      rescue NoMethodError
        datasource
      end
    }
  end

  # Return the scope but with the addition of fully qualified 
  #   variable keys for any level of the hierarchy that's formatted that way, e.g.:
  #       { 'datacenter' => 'pdx', '::datacenter' => 'pdx' } 
  #
  # @note needs to be moved to Node
  # @param args [{:scope => Hash}]
  # @return [Hash] 
  def top_scopify(args)
    scope = args[:scope]
    fix_keys = hierarchy_variables.select{|datasource| datasource.start_with?(Parameter.top_scope)}
    scope.inject({}){|a,fact|
      a[Parameter.top_scope(fact.first)] = fact.last if fix_keys.include?(Parameter.top_scope(fact.first))
      a[fact.first] = fact.last
      a }
  end

  # Basically shadows the Hiera#lookup method
  #
  # @note needs to be moved to Node#lookup
  # @param args [{:key => String, :scope => Hash, :resolution_type => Symbol}]
  # @return [Hash]
  def lookup(args = {})
    raise ArgumentError, 'HieraController#lookup requires both :key and :scope args' unless args[:key] and args[:scope]
    key = args[:key]
    scope = top_scopify(:scope => args[:scope])
    resolution_type = args[:resolution_type] || :priority
    Hash[*[key,hiera.lookup(key, nil, scope, nil, resolution_type)]]
  end

  # Retrieve all node values for all known hiera keys
  #
  # @param args [{:scope => Hash}]
  # @return [Hash]
  def get_all(args)
    scope = top_scopify(:scope => args[:scope])
    values = keys.inject({}){|a, k|
      v = lookup(:key => k, :scope => scope)
      a.merge({k => v}) }
    if args[:additive_keys]
      additive_values = args[:additive_keys].inject({}){|a,k|
        v = lookup_additive(:key => k, :scope => scope)
        a.merge({k => v}) }
      values = values.delete_if {|k,v| additive_values.has_key?(k)}.merge!(additive_values)
    end
    values.each {|k, v|
      p "DEBUG: #{k} was found in #{$mq.pop(k).join(', ')}" }
    values
  end

  # Check return value of priority lookup in order to determine which "additive"
  # resolution type to use, then repeat the lookup with the correct resolution type
  #
  # @param args [{:key => String, :scope => Hash}]
  # @return [Hash]
  def lookup_additive(args)
    key = args[:key]
    scope = top_scopify(:scope => args[:scope])
    value = lookup(:key => key, :scope => scope)
    lookup_type = 
      case value.values.pop
      when Hash
        :hash
      when TrueClass, FalseClass
        :priority
      else
        :array
      end
    lookup(:key => key, :scope => scope, :resolution_type => lookup_type)
  end
end
