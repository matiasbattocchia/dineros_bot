class Alias < Sequel::Model
  one_to_many :transactions

  # user_id  alias  status
  # -------  -----  ------
  # yes      yes    real
  # yes      no     -
  # no       yes    virtual
  # no       no     inactive

  def self.find_user(chat_id, _alias)
    raise BotError, t[:alias][:no_alias] if _alias.empty?

    user = Alias[chat_id: chat_id, alias: _alias]

    raise BotError, t[:alias][:not_found] % {alias: _alias} unless user

    user
  end

  def self.active_users(chat_id)
    where(chat_id: chat_id).exclude(alias: nil)
  end

  def self.create_virtual_user(chat_id, name)
    raise BotError, t[:alias][:long_name] % {name: name} if name.length > 16

    _alias = choose_alias(chat_id, name)

    create(
      chat_id:    chat_id,
      alias:      _alias,
      first_name: name)
  end

  def self.create_real_user(chat_id, telegram_user)
    if user = first(chat_id: chat_id, user_id: telegram_user.id)
      raise BotError, t[:alias][:existent] %
        {existent: user.first_name, to_be_created: telegram_user.first_name}
    end

    _alias = choose_alias(
      chat_id,
      telegram_user.first_name,
      telegram_user.last_name,
      telegram_user.username)

    create(
      chat_id:    chat_id,
      user_id:    telegram_user.id,
      alias:      _alias,
      first_name: telegram_user.first_name,
      last_name:  telegram_user.last_name,
      username:   telegram_user.username)
  end

  def self.delete_group(chat_id)
    DB.transaction do
      # Deletes transactions as well.
      where(chat_id: chat_id).delete
    end
  end

  def to_real_user(telegram_user)
    if user_id
      raise BotError, t[:alias][:already_real_user] %
        {existent: first_name, to_be_created: telegram_user.first_name}
    end

    update(
      user_id:    telegram_user.id,
      first_name: telegram_user.first_name,
      last_name:  telegram_user.last_name,
      username:   telegram_user.username)
  end

  def to_virtual_user
    unless user_id
      raise BotError, t[:alias][:already_virtual_user] % {name: first_name}
    end

    update(user_id: nil)
  end

  def deactivate
    unless user_id || self.alias
      raise BotError, t[:alias][:already_inactive_user] % {name: first_name}
    end

    if (balance = transactions.sum(:amount)).nonzero?
      raise BotError,
        t[:alias][:non_zero_balance] % {name: first_name, balance: balance}
    end

    if transactions.empty?
      delete
    else
      update(user_id: nil, alias: nil)
    end
  end

  private

  def self.choose_alias(chat_id, *names)
    recommended = names.compact.map{ |name| name.slice(0).downcase }
    default     = ('a'..'z').to_a
    occupied    = active_users(chat_id).select_map(:alias)

    _alias = (recommended | default - occupied).first

    _alias ||
      raise(BotError, t[:alias][:no_aliases_left] % {name: names.first})
  end
end
