require 'addressable/uri'
require 'forwardable'
require 'memoizable'
require 'twitter/null_object'
require 'twitter/utils'

module Twitter
  class Base
    extend Forwardable
    include Memoizable
    include Twitter::Utils
    attr_reader :attrs
    alias_method :to_h, :attrs
    deprecate_alias :to_hash, :to_h
    deprecate_alias :to_hsh, :to_h

    class << self
      # Define methods that retrieve the value from attributes
      #
      # @param attrs [Array, Symbol]
      def attr_reader(*attrs)
        attrs.each do |attr|
          define_attribute_method(attr)
          define_predicate_method(attr)
        end
      end

      # Define object methods from attributes
      #
      # @param klass [Symbol]
      # @param key1 [String, Symbol]
      # @param key2 [String, Symbol]
      def object_attr_reader(klass, key1, key2 = nil)
        define_attribute_method(key1, klass, key2)
        define_predicate_method(key1)
      end

      # Define URI methods from attributes
      #
      # @param attrs [Array, Symbol]
      def uri_attr_reader(*attrs)
        attrs.each do |uri_key|
          array = uri_key.to_s.split('_')
          index = array.index('uri')
          array[index] = 'url'
          url_key = array.join('_').to_sym
          define_uri_method(uri_key, url_key)
          alias_method(url_key, uri_key)
          define_predicate_method(uri_key, url_key)
          alias_method(:"#{url_key}?", :"#{uri_key}?")
        end
      end

      # Define display_uri attribute methods
      def display_uri_attr_reader
        define_attribute_method(:display_url)
        alias_method(:display_uri, :display_url)
        define_predicate_method(:display_uri, :display_url)
        alias_method(:display_url?, :display_uri?)
      end

    private

      # Dynamically define a method for a URI
      #
      # @param key1 [String, Symbol]
      # @param key2 [String, Symbol]
      def define_uri_method(key1, key2)
        define_method(key1) do ||
          Addressable::URI.parse(@attrs[key2.to_s]) unless @attrs[key2.to_s].nil?
        end
        memoize(key1)
      end

      # Dynamically define a method for an attribute
      #
      # @param key1 [String, Symbol]
      # @param klass [Symbol]
      # @param key2 [String, Symbol]
      def define_attribute_method(key1, klass = nil, key2 = nil)
        define_method(key1) do ||
          if klass.nil?
            @attrs[key1.to_s]
          else
            if @attrs[key1.to_s].nil?
              NullObject.new
            else
              attrs = attrs_for_object(key1, key2)
              Twitter.const_get(klass).new(attrs)
            end
          end
        end
        memoize(key1)
      end

      # Dynamically define a predicate method for an attribute
      #
      # @param key1 [String, Symbol]
      # @param key2 [String, Symbol]
      def define_predicate_method(key1, key2 = key1)
        define_method(:"#{key1}?") do ||
          !!@attrs[key2.to_s]
        end
        memoize(:"#{key1}?")
      end
    end

    # Initializes a new object
    #
    # @param attrs [Hash]
    # @return [Twitter::Base]
    def initialize(attrs = {})
      @attrs = attrs || {}
    end

    # Fetches an attribute of an object using hash notation
    #
    # @param method [String, Symbol] Message to send to the object
    def [](method)
      send(method.to_sym)
    rescue NoMethodError
      nil
    end

  private

    # @param key1 [String, Symbol]
    # @param key2 [String, Symbol]
    def attrs_for_object(key1, key2 = nil)
      if key2.nil?
        @attrs[key1.to_s]
      else
        attrs = @attrs.dup
        attrs.delete(key1.to_s).merge(key2.to_s => attrs)
      end
    end
  end
end
