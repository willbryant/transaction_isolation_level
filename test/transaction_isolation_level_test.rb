require 'test_helper'

class TransactionIsolationLevelTest < ActiveSupport::TestCase
  def current_isolation_level
    # we can't implement fetch_isolation_level for mysql as it does not expose the value set for
    # the transaction (as opposed to the session) - see http://bugs.mysql.com/bug.php?id=53341
    # so currently we can only run tests on postgresql.
    ActiveRecord::Base.connection.select_value "SELECT current_setting('transaction_isolation')"
  end

  test "it does nothing to queries by default" do
    default_level = current_isolation_level
    ActiveRecord::Base.transaction do
      assert_equal default_level, current_isolation_level
    end
  end

  test "it allows the isolation level to be set for the transaction, and it is reset after the transaction" do
    default_level = current_isolation_level
    ActiveRecord::Base.transaction(:isolation_level => :read_uncommitted) do
      assert_equal "read uncommitted", current_isolation_level.downcase
    end
    assert_equal default_level, current_isolation_level
    ActiveRecord::Base.transaction(:isolation_level => :read_committed) do
      assert_equal "read committed", current_isolation_level.downcase
    end
    assert_equal default_level, current_isolation_level
    ActiveRecord::Base.transaction(:isolation_level => :repeatable_read) do
      assert_equal "repeatable read", current_isolation_level.downcase
    end
    assert_equal default_level, current_isolation_level
    ActiveRecord::Base.transaction(:isolation_level => :serializable) do
      assert_equal "serializable", current_isolation_level.downcase
    end
    assert_equal default_level, current_isolation_level
  end

  test "raises an error if the requested transaction isolation level is not known" do
    assert_raises(ArgumentError) do
      ActiveRecord::Base.transaction(:isolation_level => :serialisable) {}
    end
    assert_raises(ArgumentError) do
      ActiveRecord::Base.transaction(:minimum_isolation_level => :serialisable) {}
    end
  end

  test "raises an error if a transaction is already open and the requested transaction isolation level is different to the current level" do
    ActiveRecord::Base.transaction(:isolation_level => :repeatable_read) do
      assert_raises(ActiveRecord::IncompatibleTransactionIsolationLevel) do
        ActiveRecord::Base.transaction(:isolation_level => :read_uncommitted) {}
      end
      assert_raises(ActiveRecord::IncompatibleTransactionIsolationLevel) do
        ActiveRecord::Base.transaction(:isolation_level => :read_committed) {}
      end
      assert_nothing_raised do
        ActiveRecord::Base.transaction(:isolation_level => :repeatable_read) {}
      end
      assert_raises(ActiveRecord::IncompatibleTransactionIsolationLevel) do
        ActiveRecord::Base.transaction(:isolation_level => :serializable) {}
      end
    end

    ActiveRecord::Base.transaction(:isolation_level => :read_committed) do
      assert_raises(ActiveRecord::IncompatibleTransactionIsolationLevel) do
        ActiveRecord::Base.transaction(:isolation_level => :read_uncommitted) {}
      end
      assert_nothing_raised do
        ActiveRecord::Base.transaction(:isolation_level => :read_committed) {}
      end
      assert_raises(ActiveRecord::IncompatibleTransactionIsolationLevel) do
        ActiveRecord::Base.transaction(:isolation_level => :repeatable_read) {}
      end
      assert_raises(ActiveRecord::IncompatibleTransactionIsolationLevel) do
        ActiveRecord::Base.transaction(:isolation_level => :serializable) {}
      end
    end
  end

  test "supports requesting a minimum transaction isolation level, in which case an error is raised only if requested transaction isolation level is higher than the actual transaction isolation" do
    ActiveRecord::Base.transaction(:isolation_level => :repeatable_read) do
      assert_nothing_raised do
        ActiveRecord::Base.transaction(:minimum_isolation_level => :read_uncommitted) {}
        ActiveRecord::Base.transaction(:minimum_isolation_level => :read_committed) {}
        ActiveRecord::Base.transaction(:minimum_isolation_level => :repeatable_read) {}
      end
      assert_raises(ActiveRecord::IncompatibleTransactionIsolationLevel) do
        ActiveRecord::Base.transaction(:minimum_isolation_level => :serializable) {}
      end
    end

    ActiveRecord::Base.transaction(:isolation_level => :read_committed) do
      assert_nothing_raised do
        ActiveRecord::Base.transaction(:minimum_isolation_level => :read_uncommitted) {}
        ActiveRecord::Base.transaction(:minimum_isolation_level => :read_committed) {}
      end
      assert_raises(ActiveRecord::IncompatibleTransactionIsolationLevel) do
        ActiveRecord::Base.transaction(:minimum_isolation_level => :repeatable_read) {}
        ActiveRecord::Base.transaction(:minimum_isolation_level => :serializable) {}
      end
    end
  end
end
