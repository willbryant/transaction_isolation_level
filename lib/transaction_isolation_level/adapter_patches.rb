module ActiveRecord
  module ConnectionAdapters
    module DatabaseStatements
      ORDER_OF_TRANSACTION_ISOLATION_LEVELS = [:read_uncommitted, :read_committed, :repeatable_read, :serializable]

      def transaction_isolation_level_sql(value)
        case value
        when :read_uncommitted then 'ISOLATION LEVEL READ UNCOMMITTED'
        when :read_committed   then 'ISOLATION LEVEL READ COMMITTED'
        when :repeatable_read  then 'ISOLATION LEVEL REPEATABLE READ'
        when :serializable     then 'ISOLATION LEVEL SERIALIZABLE'
        when nil               then nil
        else raise "Unknown transaction isolation level: #{value.inspect}"
        end
      end

      def transaction_isolation_level_from_sql(value)
        case value.gsub('-', ' ').upcase
        when 'READ UNCOMMITTED' then :read_uncommitted
        when 'READ COMMITTED'   then :read_committed
        when 'REPEATABLE READ'  then :repeatable_read
        when 'SERIALIZABLE'     then :serializable
        else raise "Unknown transaction isolation level: #{value.inspect}"
        end
      end

      def transaction_with_isolation_level(**options)
        isolation_level = options.delete(:isolation_level)
        minimum_isolation_level = options.delete(:minimum_isolation_level)

        raise ArgumentError,         "#{isolation_level.inspect} is not a known transaction isolation level" unless         isolation_level.nil? || ORDER_OF_TRANSACTION_ISOLATION_LEVELS.include?(isolation_level)
        raise ArgumentError, "#{minimum_isolation_level.inspect} is not a known transaction isolation level" unless minimum_isolation_level.nil? || ORDER_OF_TRANSACTION_ISOLATION_LEVELS.include?(minimum_isolation_level)

        if open_transactions == 0
          @transaction_isolation_level = isolation_level || minimum_isolation_level
        elsif isolation_level && isolation_level != (@transaction_isolation_level || default_transaction_isolation_level)
          raise IncompatibleTransactionIsolationLevel, "Asked to use transaction isolation level #{isolation_level}, but the transaction has already begun with isolation level #{@transaction_isolation_level || default_transaction_isolation_level}"
        end
        if minimum_isolation_level && ORDER_OF_TRANSACTION_ISOLATION_LEVELS.index(minimum_isolation_level) > ORDER_OF_TRANSACTION_ISOLATION_LEVELS.index(@transaction_isolation_level || default_transaction_isolation_level)
          raise IncompatibleTransactionIsolationLevel, "Asked to use transaction isolation level at least #{minimum_isolation_level}, but the transaction has already begun with isolation level #{@transaction_isolation_level || default_transaction_isolation_level}"
        end

        transaction_without_isolation_level(**options) { yield }
      end

      alias :transaction_without_isolation_level :transaction
      alias :transaction :transaction_with_isolation_level
    end

    class AbstractAdapter
      attr_reader :default_transaction_isolation_level, :transaction_isolation_level

      def commit_db_transaction #:nodoc:
        super
      ensure
        @transaction_isolation_level = nil
      end

      def rollback_db_transaction #:nodoc:
        super
      ensure
        @transaction_isolation_level = nil
      end
    end

    module PostgreSQLAdapterPatches
      def begin_db_transaction
        execute "BEGIN TRANSACTION #{transaction_isolation_level_sql(@transaction_isolation_level)}"
      end

      # the postgresql adapter calls configure_connection part way through its #initialize.  after that point, it sets
      # @type_map.  however, by calling execute, our overridden configure_connection will run a query, and this requires
      # a type map, which needs to be the postgresql-specific type that #initialize would instantiate, not the default
      # created by #type_map in the abstract adapter code.  so we override that default to be the same as #initialize
      # will make.
      def type_map
        return @type_map if instance_variable_defined?(:@type_map)
        @type_map =
          if PostgreSQLAdapter::OID.const_defined?(:TypeMap)
            # 5.0 and below
            PostgreSQLAdapter::OID::TypeMap.new
          else
            # 5.1 and above
            Type::HashLookupTypeMap.new
          end
        initialize_type_map(type_map)
        @type_map
      end

      def configure_connection
        super
        if @config[:transaction_isolation_level]
          @default_transaction_isolation_level = @config[:transaction_isolation_level].to_sym
          execute "SET SESSION CHARACTERISTICS AS TRANSACTION #{transaction_isolation_level_sql default_transaction_isolation_level}"
        else
          @default_transaction_isolation_level = transaction_isolation_level_from_sql(select_value("SELECT current_setting('default_transaction_isolation')"))
        end
      end
    end

    module MysqlAdapterPatches
      def begin_db_transaction
        execute "SET TRANSACTION #{transaction_isolation_level_sql(@transaction_isolation_level)}" if @transaction_isolation_level # applies only to the next transaction
        super
      end

      def configure_connection
        super
        if @config[:transaction_isolation_level]
          @default_transaction_isolation_level = @config[:transaction_isolation_level].to_sym
          execute "SET SESSION TRANSACTION #{transaction_isolation_level_sql default_transaction_isolation_level}"
        else
          @default_transaction_isolation_level = transaction_isolation_level_from_sql(select_value("SELECT @@session.tx_isolation"))
        end
      end
    end

    PostgreSQLAdapter.class_eval do
      prepend PostgreSQLAdapterPatches
    end if const_defined?(:PostgreSQLAdapter)

    MysqlAdapter.class_eval do
      prepend MysqlAdapterPatches
    end if const_defined?(:MysqlAdapter)

    Mysql2Adapter.class_eval do
      prepend MysqlAdapterPatches
    end if const_defined?(:Mysql2Adapter)
  end
end
