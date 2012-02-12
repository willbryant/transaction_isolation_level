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
        require 'transaction_isolation_level/adapter_patches'
        establish_connection_without_isolation_level_adapter_patches(*args)
      end

      alias_method :establish_connection_without_isolation_level_adapter_patches, :establish_connection
      alias_method :establish_connection, :establish_connection_with_isolation_level_adapter_patches
    end
  end
end
