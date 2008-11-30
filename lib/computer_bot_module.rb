module Computer #:nodoc:
  module Bot #:nodoc:
    # This class represents a bot module
    module Module
      # Every bot module must implement this method. Here, the module should
      # initialize his own structures, and keep the references to the Bot,
      # Config and Logger objects
      #
      # name:: The namespace that this module should use to register the
      #        the commands and to store values on the persistence layer
      # bot::  A reference to the bot object. The client should use this
      #        reference to register the commads under his namespace. It
      #        should also be used when you want to send a message to a
      #        client.
      # config:: An optional hash with parameters specified by the client
      #          on the configuration files
      # logger:: A reference to the global logger object. It should be
      #          used everytime we need to output log information
      def initialize(name, bot, config, logger)
        raise "initialize(name, bot, config, logger) should be implemented"
      end
    end
  end
end
