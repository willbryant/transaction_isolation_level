require 'active_record'
require 'active_record/connection_adapters/abstract/connection_pool'

module ActiveRecord
  class IncompatibleTransactionIsolationLevel < StandardError; end

  module ConnectionAdapters
    class ConnectionHandler
      # ActiveRecord only loads the adapters actually used for connections, so we can't patch their
      # classes until we know which one will be loaded.  however, the adapter classes are not statically
      # required; they are only loaded when ActiveRecord::Base#establish_connection retrieves them from
      # the connection spec.  that has several code paths to handle different arguments but eventually
      # uses the ConnectionHandler#establish_connection method we override here to load our patches once
      # ActiveRecord::Base#establish_connection has loaded the class to patch.
      def establish_connection_with_isolation_level_adapter_patches(*args)
        if ActiveRecord::VERSION::MAJOR == 6 && ActiveRecord::VERSION::MINOR > 0
          # establish_connection sets up a pool without actually literally establishing a connection any more,
          # so we can patch the adapter after this require now
          establish_connection_without_isolation_level_adapter_patches(*args)
          require 'transaction_isolation_level/adapter_patches'
        else
          if (ActiveRecord::VERSION::MAJOR == 5 && ActiveRecord::VERSION::MINOR > 0) || ActiveRecord::VERSION::MAJOR > 5
            # need to explicitly trigger load of the adapter for 5.1 and above, as from that point on its
            # required only in establish_connection, and we don't have a way to insert our patches halfway
            # through that method.
            ConnectionSpecification::Resolver.new(Base.configurations).spec(args.last)
          end

          require 'transaction_isolation_level/adapter_patches'
          establish_connection_without_isolation_level_adapter_patches(*args)
        end
      end

      alias_method :establish_connection_without_isolation_level_adapter_patches, :establish_connection
      alias_method :establish_connection, :establish_connection_with_isolation_level_adapter_patches
    end
  end
end
