module Computer #:nodoc:
  module Bot #:nodoc:
    # Interface to be used for each persistence module. A persistence
    # module implements a service that allows anyone to store pairs
    # in the form of [key, value], under a namespace, with persistence
    # storage. It should be used to store persistant data from each
    # bot module.
    module Persistence
      # Each module should initialize the underling
      # structures of the persistant layer.
      #
      # config:: A (possible empty) hash of configurations parameters.
      #          The user can suplly these options by filling the
      #          appropriate fields on the configuration YAML file
      # logger:: A reference to the global logger object. It should be
      #          used everytime we need to output log information
      def initialize(config, logger)
        raise "initialize(config, logger) should be implemented"
      end

      # Writes a pair [_key_, _value_] on the persistence layer, under the
      # specified _namepsace_.
      #
      # namespace:: A String representing the namespace that should be
      #             used to store the pair of data
      # key:: A String representing a key
      # value:: A String representing a value associated with the key
      def write(namespace, key, value)
        raise "write(namespace, key, value) should be implemented"
      end
      
      # Reads the value associated with the _key_ under the _namespace_.
      # If the _key_ does not exists under the _namespace_, this method
      # will return +nil+.
      #
      # namespace:: A String representing the namespace that should be
      #             used to read the key's value
      # key:: A String representing the key we are interested
      def read(namespace, key)
        raise "read(namespace, key) should be implemented"
      end
    end
  end
end
