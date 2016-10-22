require 'sequel'

DB = Sequel.connect('postgres://localhost/dineros')

DB.create_table? :aliases do
  primary_key :id

  Bignum :chat_id, null: false
  Fixnum :user_id
  String :alias, size: 1, fixed: true

  String :first_name, size: 32, null: false
  String :last_name,  size: 32
  String :username,   size: 32

  unique [:chat_id, :user_id]
  unique [:chat_id, :alias]
end

DB.create_table? :transactions do
  foreign_key :alias_id, :aliases, on_delete: :cascade

  Bignum :chat_id,    null: false
  Fixnum :payment_id, null: false
  Fixnum :amended_payment_id
  Date   :date,       null: false
  String :concept,    size: 32, null: false
  BigDecimal :contribution, size: [19, 4], null: false
  BigDecimal :factor, size: [19, 4], null: false
  BigDecimal :amount, size: [19, 4], null: false

  constraint(:factor_min_value){ factor >= 0 }

  index  [:chat_id,  :payment_id]
  #index  [:chat_id,  :amended_payment_id]
  unique [:alias_id, :payment_id]
end

DB.create_table? :accounts do
  foreign_key :alias_id, :aliases

  Date :date, null: false
  BigDecimal :balance, size: [19, 4], null: false

  index :alias_id
end

DB.create_table? :rrpps do
  Fixnum :user_id, primary_key: true
  String :first_name, size: 32, null: false
  String :last_name,  size: 32
end

DB.create_table? :recommendations do
  foreign_key :rrpp_id

  Fixnum :user_id, primary_key: true
  String :first_name, size: 32, null: false
  String :last_name,  size: 32
end
