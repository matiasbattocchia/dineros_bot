require 'sequel'

DB = Sequel.connect('postgres://localhost/dineros')

DB.create_table? :aliases do
  Fixnum :user_id
  Bignum :chat_id
  String :alias, null: false

  primary_key [:user_id, :chat_id]
  index [:chat_id, :alias], unique: true
end

DB.create_table? :transactions do
  Fixnum :user_id
  Bignum :chat_id
  Fixnum :message_id
  Date   :date, null: false
  String :concept, null: false
  BigDecimal :contribution, size: [19, 4], null: false
  BigDecimal :expense_factor, size: [19, 4], null: false
  BigDecimal :amount, size: [19, 4], null: false

  primary_key [:user_id, :chat_id, :message_id]
  index [:chat_id, :message_id]
end

DB.create_table? :accounts do
  Fixnum :user_id, null: false
  Bignum :chat_id, null: false
  Date :date, null: false
  BigDecimal :balance, size: [19, 4], null: false

  index [:user_id, :chat_id]
end
