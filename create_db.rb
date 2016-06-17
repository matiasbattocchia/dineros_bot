require 'sequel'

DB = Sequel.connect('postgres://localhost/dineros')

DB.create_table? :aliases do
  primary_key :id

  Fixnum :user_id
  Bignum :chat_id, null: false
  String :alias, null: false
  String :name, null: false

  unique [:user_id, :chat_id]
  index  [:chat_id, :alias], unique: true
end

DB.create_table? :transactions do
  foreign_key :alias_id, :aliases

  Fixnum :message_id, null: false
  Date   :date, null: false
  String :concept, null: false
  BigDecimal :contribution, size: [19, 4], null: false
  BigDecimal :factor, size: [19, 4], null: false
  BigDecimal :amount, size: [19, 4], null: false

  unique [:alias_id, :message_id]
  index  :alias_id
end

DB.create_table? :accounts do
  foreign_key :alias_id, :aliases

  Date :date, null: false
  BigDecimal :balance, size: [19, 4], null: false

  index :alias_id
end
