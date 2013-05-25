require 'sqlite3'

module Bitbot
  class InsufficientFundsError < StandardError; end

  class Database
    def initialize(path)
      @db = SQLite3::Database.new path
      @db.execute('PRAGMA foreign_keys = ON')
    end

    def upgrade_schema
      @db.execute(<<-ENDSQL)
        create table if not exists users (
          id integer primary key autoincrement,
          created_at integer not null,
          username text not null unique
        )
      ENDSQL

      @db.execute(<<-ENDSQL)
        create table if not exists transactions (
          id integer primary key autoincrement,
          created_at integer not null,
          amount numeric not null,
          note text,
          withdrawal_address text,
          incoming_transaction text unique,
          user_id int references users(id) not null,
          other_user_id int references users(id)
        )
      ENDSQL
    end

    def get_or_create_user_id_for_username(username)
      user_id = @db.get_first_value("select id from users where username = ?", [ username ])
      unless user_id
        @db.execute("insert into users(created_at, username) values (?, ?)", [ Time.now.to_i, username ])
        user_id = @db.get_first_value("select last_insert_rowid()")
      end

      user_id
    end

    def get_username_for_user_id(user_id)
      @db.get_first_value("select username from users where id = ?", [ user_id ])
    end

    def get_balance_for_user_id(user_id)
      @db.get_first_value("select coalesce(sum(amount), 0) from transactions where user_id = ?", [ user_id ])
    end

    def get_transactions_for_user_id(user_id)
      result = []
      @db.execute("select t.id, t.created_at, t.amount, t.note, t.withdrawal_address, t.incoming_transaction, t.other_user_id, u.username from transactions t left outer join users u on t.other_user_id = u.id where user_id = ? order by t.created_at desc", [ user_id ]) do |row|
        result << {
          :id => row[0],
          :created_at => row[1],
          :amount => row[2],
          :note => row[3],
          :withdrawal_address => row[4],
          :incoming_transaction => row[5],
          :other_user_id => row[6],
          :other_username => row[7]
        }
      end
      result
    end

    def get_tipping_stats(from = nil)
      # If no from is specified, use midnight of today.
      if from.nil?
        # TODO: this is hardcoding an offset of -0700 - fix that to make
        # the timezone configurable
        now = Time.now - 60 * 60 * 7
        from = Time.local(now.year, now.month, now.day)
      end
      from = from.to_i

      stats = {}
      
      stats[:total_tipped] = @db.get_first_value("select coalesce(sum(amount), 0) from transactions t where t.other_user_id is not null and t.user_id <> t.other_user_id and t.amount < 0 and t.created_at > ?", [ from ])
      stats[:total_tips] = @db.get_first_value("select count(*) from transactions t where t.other_user_id is not null and t.user_id <> t.other_user_id and t.amount < 0 and t.created_at > ?", [ from ])
      stats[:tippers] = @db.execute("select * from (select username, sum(amount) total from transactions t, users u where t.user_id = u.id and other_user_id is not null and amount < 0 and user_id <> other_user_id and t.created_at >= ? group by username) foo order by total asc", [ from ])
      stats[:tippees] = @db.execute("select * from (select username, sum(amount) total from transactions t, users u where t.user_id = u.id and amount > 0 and user_id <> other_user_id and t.created_at >= ? group by username) foo order by total desc", [ from ])
      stats
    end

    # Returns an array of all the Bitcoin transaction ids for deposits
    def get_incoming_transaction_ids
      transaction_ids = []
      @db.execute("select incoming_transaction from transactions where incoming_transaction is not null") do |row|
        transaction_ids << row[0]
      end

      transaction_ids
    end

    # Adds a transaction with a deposit. Returns true if the row was
    # added, and false if the insert failed for some reason (like if the
    # transaction_id already exists).
    def create_transaction_from_deposit(user_id, amount, transaction_id)
      @db.execute("insert into transactions (created_at, amount, incoming_transaction, user_id) values (?, ?, ?, ?)",
                  [ Time.now.to_i, amount, transaction_id, user_id ])
      return @db.changes == 1
    end

    # Adds a transaction for a withdrawal.
    def create_transaction_from_withdrawal(user_id, amount, fee, address)
      @db.transaction(:exclusive) do
        # verify current balance
        current_balance = self.get_balance_for_user_id(user_id)
        if current_balance < (amount + fee)
          raise InsufficientFundsError, "Insufficient funds; Current balance: #{current_balance} for amount #{amount} + fee #{fee}"
        end

        @db.execute("insert into transactions (created_at, user_id, amount, withdrawal_address)
                     values (?, ?, ?, ?)", [ Time.now.to_i, user_id, (0 - (amount + fee)), address ])
      end

      true
    end

    def create_transaction_from_tip(from_user_id, to_user_id, amount, message)
      @db.transaction(:exclusive) do
        # verify current balance
        current_balance = self.get_balance_for_user_id(from_user_id)
        if current_balance < amount
          raise InsufficientFundsError, "Insufficient funds; Current balance: #{current_balance} for amount #{amount}"
        end

        now = Time.now.to_i
        @db.execute("insert into transactions (created_at, user_id, amount, note, other_user_id)
                    values (?, ?, ?, ?, ?)", [ now, from_user_id, (0 - amount), message, to_user_id ])
        @db.execute("insert into transactions (created_at, user_id, amount, note, other_user_id)
                    values (?, ?, ?, ?, ?)", [ now, to_user_id, amount, message, from_user_id ])
      end

      true
    end
  end
end
