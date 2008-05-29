require 'singleton'
require 'find'

module YARD
  class Registry
    DEFAULT_YARDOC_FILE = ".yardoc"
    
    include Singleton
  
    @objects = {}

    class << self
      attr_reader :objects

      def method_missing(meth, *args, &block)
        if instance.respond_to? meth
          instance.send(meth, *args, &block)
        else
          super
        end
      end
      
      def clear
        instance.clear 
        objects.clear
      end
      
      def resolve(namespace, name, proxy_fallback = false)
        namespace = Registry.root if namespace == :root || !namespace
        
        newname = name.to_s.gsub(/^#/, '')
        if name =~ /^::/
          [name, newname[2..-1]].each do |n|
            return at(n) if at(n)
          end
        else
          while namespace
            [CodeObjects::NSEP, CodeObjects::ISEP].each do |s|
              path = newname
              if namespace != root
                path = [namespace.path, newname].join(s)
              end
              found = at(path)
              return found if found
            end
            namespace = namespace.parent
          end
          
          # Look for ::name or #name in the root space
          [CodeObjects::NSEP, CodeObjects::ISEP].each do |s|
            found = at(s + newname)
            return found if found
          end
        end
        proxy_fallback ? CodeObjects::Proxy.new(namespace, name) : nil
      end
    end

    def load(reload = false, file = DEFAULT_YARDOC_FILE)
      if File.exists?(file) && !reload
        namespace.replace(Marshal.load(IO.read(file)))
      else
        Find.find(".") do |path|
          Parser::SourceParser.parse(path) if path =~ /\.rb$/
          save
        end
      end
      nil
    end
    
    def save(file = DEFAULT_YARDOC_FILE)
      File.open(file, "w") {|f| Marshal.dump(@namespace, f) }
    end

    def all(*types)
      namespace.values.select do |obj| 
        if types.empty?
          obj != Registry.root
        else
          obj != Registry.root &&
            types.any? do |type| 
              type.is_a?(Symbol) ? obj.type == type : obj.is_a?(type)
            end
        end
      end
    end
    
    def paths
      namespace.keys.map {|k| k.to_s }
    end
      
    def at(path) path.to_s.empty? ? root : namespace[path] end
    alias_method :[], :at
    
    def root; namespace[:root] end
    def delete(object) namespace.delete(object.path) end
    def clear; initialize end

    def initialize
      @namespace = SymbolHash.new
      @namespace[:root] = CodeObjects::RootObject.new(nil, :root)
    end
  
    def register(object)
      return if object.is_a?(CodeObjects::Proxy)
      namespace[object.path] = object
    end

    private
  
    attr_accessor :namespace
    
  end
end