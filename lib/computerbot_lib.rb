require 'rubygems'
require 'logger'
require 'yaml'
require 'eventmachine'

$LOAD_PATH.unshift File.dirname(__FILE__)

require 'computer_bot_persistence'
require 'computer_bot_module'
# Uses the jabber_bot.rb lib directly instead of the rubygem
require File.dirname(__FILE__) + '/jabber_bot.rb'

Thread.abort_on_exception = true # helps debugging threads

module Computer #:nodoc:
  module Bot #:nodoc:
    # Computerbot interface. This class holds all the methods that can be
    # used by the modules to interact with the clients.
    class Base
      # The _persistence_ property holds a reference to the current persistence
      # module being used on this configuration.
      attr_reader :persistence

      # When calling the constructor, the module loads a config file, initializes
      # the modules specified on the config, connects the bot to the Jabber server
      # and starts listening for requests. This method will only return if the bot
      # receives the order to shutdown.
      def initialize
        # Loads the config file
        @config = YAML::load(IO::read(File.dirname(__FILE__) + "/config/#{ENV_SET}.yml"))

        # Configure logger
        if @config['general']['verbose']
          @logger = Logger.new(STDERR)
        else
          @logger = Logger.new('/dev/null')
        end
        @logger.level = Logger::INFO # XXX: this should be configurable on yaml

        # Initialize Persistence configuration
        configure_persistence(@config['general']['persistence'])
            
        # Initializes the Jabber bot
        @bot = Jabber::Bot.new(
          :jabber_id => @config['bot']['username'], 
          :password  => @config['bot']['password'], 
          :master    => @config['bot']['master'],
          :presence  => @config['bot']['presence'] ? @config['bot']['presence'].to_sym : :chat,
          :status    => @config['bot']['status'],
          :resource  => @config['bot']['resource'] || 'Bot',
          :is_public => @config['bot']['is_public'] || false,
          :logger    => @logger
        )
        
        # Loads default commands
        load_commands!

        # Register each module on the config
        configure_modules(@config['modules'])
        
        # Start the all things up
        EventMachine::run {
          @operation = proc do
            @bot.connect
          end

          @callback = proc do
            puts "The end :-)"
          end

          EventMachine::defer(@operation, @callback)
        }
      end

      # Register a new command with computerbot. This method should receive
      # a number of arguments, and a required callback that should be called
      # everytime the registered command is triggered.
      #
      # syntax:: A text that describes the syntax of the command in a user friendly way
      # description:: A text that resumes what the command does
      # regex:: A Regex that is used to trigger this command
      # namespace:: A (optional) String representing the namespace where this
      #             module should be registered. A module should always use the
      #             same namespace to register the different modules
      # is_public:: if +true+, than the bot will try to trigger the command with the
      #             messages from all buddies. Otherwise, it will only try to match
      #             with the bot masters.
      # callback:: The callback will be called when this command is triggered. It will
      #            be called with two parameters: _sender_ and _message_. The module
      #            can use the _message_ to extract more data from the command, and
      #            then send back a message to the sender. As a bonus, everything that
      #            you return from the callback will automaticly be sent to the sender.
      #            You can prevent this beaviour by returning +nil+.
      def add_command(*args, &callback)
        @bot.add_command(*args, &callback)
      end

      # Delivers a message to a _recipient_.
      #
      # recipient:: An object representing a recipient
      # message:: A String with the message to send, or an Array of
      #           messages that will be sent in order.
      def deliver(recipient, message)
        if message.is_a?(Array)
          message.each { |message| @bot.deliver(recipient, message)}
        else
          @bot.deliver(recipient, message)
        end
      end
  
      # Register a periodic event on the event loop. This method returns
      # an instance of PeriodicEvent that should be kept if the event should
      # be cancelled in the future.
      #
      # interval:: the number of seconds that the event should be triggered
      # block:: a block of code that is called everytime the event is triggered
      def register_periodic_event(interval, &block)
        PeriodicEvent.new(interval, &block)
      end
  
      private
      def load_commands!
        @bot.add_command(
          :syntax      => 'ping',
          :description => 'Returns a pong and a timestamp',
          :regex       => /^ping$/,
          :is_public   => false
        ) do
          "Pong! (#{Time.now})"
        end
           
        @bot.add_command(
          :syntax      => 'bye',
          :description => 'Swiftly disconnects the bot',
          :regex       => /^bye$/,
          :is_public   => false
        ) do |sender, message| execute_bye_command(sender, message)
        nil
        end    
      end # load_commands
      
      def execute_bye_command(sender,message)
        deliver(sender, 'Bye bye.')
        @bot.disconnect
        exit
      end

      def configure_persistence(config)
        unless config['class']
          @logger.fatal "You need to specify a persistence class on your config"
          exit
        end

        file = config['file']
        klass = config['class']

        begin
          eval "require '#{file}'"
          @persistence = (eval klass)
          @persistence = @persistence.new(config['config'], @logger)
        rescue LoadError => e
          @logger.fatal "Couldn't find #{file} on the current path"
          raise e
        rescue NameError => e
          @logger.fatal "Couldn't instanciate #{klass}. Maybe it's not defined in #{file}"
          raise e
        end
      end # configure_persistence

      def configure_modules(config)
        config.each do |mod|
          name = mod['name']
          file = mod['file']
          klass = mod['class']

          begin
            eval "require '#{file}'"
            instance = (eval klass)
            instance = instance.new(name, self, mod['config'], @logger)
          rescue LoadError => e
            @logger.fatal "Couldn't find #{file} on the current path"
            raise e
          rescue NameError => e
            @logger.fatal "Couldn't instanciate #{klass}. Maybe it's not defined in #{file}"
            raise e
          end
        end
      end

      # A periodic event class. We use the EventMachine::PeriodicTimer
      # to implement the interface to the event loop
      class PeriodicEvent < EventMachine::PeriodicTimer
        # Initializes the periodic timer. It accepts a interval in seconds
        # and a block of code that should be called when the event is fired.
        def initialize(interval, &block)
          super(interval)

          @operation = proc do
            block.call unless @cancelled
          end

          @callback = proc do
            schedule unless @cancelled
          end
        end

        # Called by the event loop to fire this event. The code is run
        # on a separate thread, and when if finishes, the event is rescheduled.
        # So there is no need to worry about this event being fired while the
        # previous one is still running.
        def fire
          EventMachine::defer(@operation, @callback)
        end
      end
    end # Base
  end # Bot 
end # Computer 

Computer::Bot::Base.new # executes everything when this file is called by computerbot.rb. You will never create another Bot object :)

