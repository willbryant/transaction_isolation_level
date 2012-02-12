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

      def transaction_with_isolation_level(options = {})
        isolation_level = options.delete(:isolation_level)
        minimum_isolation_level = options.delete(:minimum_isolation_level)

        raise ArgumentError,         "#{isolation_level.inspect} is not a known transaction isolation level" unless         isolation_level.nil? || ORDER_OF_TRANSACTION_ISOLATION_LEVELS.include?(isolation_level)
        raise ArgumentError, "#{minimum_isolation_level.inspect} is not a known transaction isolation level" unless minimum_isolation_level.nil? || ORDER_OF_TRANSACTION_ISOLATION_LEVELS.include?(minimum_isolation_level)

        if open_transactions == 0
          @transaction_isolation_level = isolation_level || minimum_isolation_level
        elsif isolation_level && isolation_level != @transaction_isolation_level
          raise IncompatibleTransactionIsolationLevel, "Asked to use transaction isolation level #{isolation_level}, but the transaction has already begun with isolation level #{@transaction_isolation_level || :unknown}"
        end
        if minimum_isolation_level && ORDER_OF_TRANSACTION_ISOLATION_LEVELS.index(minimum_isolation_level) > ORDER_OF_TRANSACTION_ISOLATION_LEVELS.index(@transaction_isolation_level)
          raise IncompatibleTransactionIsolationLevel, "Asked to use transaction isolation level at least #{minimum_isolation_level}, but the transaction has already begun with isolation level #{@transaction_isolation_level || :unknown}"
        end

        transaction_without_isolation_level(options) { yield }
      end

      alias_method :transaction_without_isolation_level, :transaction
      alias_method :transaction, :transaction_with_isolation_level
    end

    class AbstractAdapter
      attr_reader :transaction_isolation_level

      def commit_db_transaction #:nodoc:
        super
      ensure
        @transaction_isolation_level = nil
      end

      def rollback_db_transaction #:nodoc:
        super
      ensure
        @transaction_isolation_level
      end
    end

    PostgreSQLAdapter.class_eval do
      def begin_db_transaction
        execute "BEGIN TRANSACTION #{transaction_isolation_level_sql(@transaction_isolation_level)}"
      end
    end if const_defined?(:PostgreSQLAdapter)

    module MysqlAdapterPatches
      def begin_db_transaction
        execute "SET TRANSACTION #{transaction_isolation_level_sql(@transaction_isolation_level)}" if @transaction_isolation_level # applies only to the next transaction
        super
      end
    end

    MysqlAdapter.class_eval do
      include MysqlAdapterPatches
    end if const_defined?(:MysqlAdapter)

    Mysql2Adapter.class_eval do
      include MysqlAdapterPatches
    end if const_defined?(:Mysql2Adapter)
  end
end
