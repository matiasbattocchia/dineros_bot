class User < Sequel::Model
  unrestrict_primary_key

  many_to_one :referred_by, class: self
  one_to_many :referrals, key: :referred_by_id, class: self

  many_to_many :chats
end

class Chat < Sequel::Model
  unrestrict_primary_key

  many_to_many :users
end
