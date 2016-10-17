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
    where(chat_id: chat_id).exclude(alias: nil).order(:first_name, :last_name)
  end

  def self.real_users(chat_id)
    where(chat_id: chat_id).exclude(user_id: nil, alias: nil)
      .order(:first_name, :last_name)
  end

  def self.virtual_users(chat_id)
    where(chat_id: chat_id, user_id: nil).exclude(alias: nil)
      .order(:first_name, :last_name)
  end

  def self.create_virtual_user(chat_id, name)
    raise BotError, t[:alias][:long_name] % {name: name} if name.length > 32

    _alias = choose_alias(chat_id, name)

    create(
      chat_id:    chat_id,
      alias:      _alias,
      first_name: name)
  end

  def self.create_real_user(chat_id, telegram_user)
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

  def self.obliterate(chat_id)
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
      raise BotError, t[:alias][:already_virtual_user] % {name: full_name}
    end

    update(user_id: nil)
  end

  def deactivate
    unless user_id || self.alias
      raise BotError, t[:alias][:already_inactive_user] % {name: full_name}
    end

    if balance.nonzero?
      raise BotError, t[:alias][:non_zero_balance] %
        {name: first_name, balance: money_helper(balance)}
    end

    if transactions.empty?
      delete
    else
      update(user_id: nil, alias: nil)
    end
  end

  #def update
    #result = u.update(
      #alias: a,
      #first_name: user.first_name,
      #last_name: user.last_name,
      #username: user.username)

    ## result.nil? means that the record was not updated because
    ## it has not changed, but everything is fine.
    #if result || result.nil?
      #render(t[:alias][:updated] % {name: full_name, alias: _alias})
    #end
  #end

  def full_name
    name_helper(first_name, last_name, user_id)
  end

  def balance
    transactions_dataset.sum(:amount) || BigDecimal(0)
  end

  def self.choose_alias(chat_id, *names)
    recommended = names.compact.map{ |name| name.slice(0).downcase }
    default     = ('a'..'z').to_a
    occupied    = active_users(chat_id).select_map(:alias)

    _alias = ((recommended | default) - occupied).first

    _alias ||
      raise(BotError, t[:alias][:no_aliases_left] % {name: names.first})
  end
end
