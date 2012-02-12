module ActiveRecord
  module ConnectionAdapters
    module DatabaseStatements
      def transaction_with_isolation_level(options = {})
        isolation_level = options.delete(:isolation_level)
        if open_transactions == 0
          @transaction_isolation_level = isolation_level
        elsif isolation_level && isolation_level != @transaction_isolation_level
          raise IncompatibleTransactionIsolationLevel, "Asked to use transaction isolation level #{isolation_level}, but the transaction has already begun with isolation level #{@transaction_isolation_level || :unknown}"
        end

        transaction_without_isolation_level(options) { yield }
      end

      alias_method :transaction_without_isolation_level, :transaction
      alias_method :transaction, :transaction_with_isolation_level
    end

    class AbstractAdapter
      attr_reader :transaction_isolation_level

      def transaction_isolation_level_sql
        case @transaction_isolation_level
        when :read_uncommitted then 'ISOLATION LEVEL READ UNCOMMITTED'
        when :read_committed   then 'ISOLATION LEVEL READ COMMITTED'
        when :repeatable_read  then 'ISOLATION LEVEL REPEATABLE READ'
        when :serializable     then 'ISOLATION LEVEL SERIALIZABLE'
        when nil               then nil
        else raise "Unknown transaction isolation level: #{@transaction_isolation_level.inspect}"
        end
      end

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
        execute "BEGIN TRANSACTION #{transaction_isolation_level_sql}"
      end
    end if const_defined?(:PostgreSQLAdapter)

    MysqlAdapter.class_eval do
      def begin_db_transaction
        execute "SET TRANSACTION #{transaction_isolation_level_sql}" if transaction_isolation_level # applies only to the next transaction
        super
      end
    end if const_defined?(:MysqlAdapter)

    Mysql2Adapter.class_eval do
      def begin_db_transaction
        execute "SET TRANSACTION #{transaction_isolation_level_sql}" if transaction_isolation_level # as above
        super
      end
    end if const_defined?(:Mysql2Adapter)
  end
end
