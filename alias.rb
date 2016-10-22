class Alias < Sequel::Model
  one_to_many :transactions

  # user_id  alias  status
  # -------  -----  ------
  # yes      yes    real
  # yes      no     -
  # no       yes    virtual
  # no       no     inactive

  def real_user?
    user_id && self.alias
  end

  def virtual_user?
    !user_id && self.alias
  end

  def active_user?
    self.alias
  end

  def self.find_user(chat_id, _alias)
    raise BotError, t[:alias][:no_alias] if _alias.nil?

    user = Alias[chat_id: chat_id, alias: _alias]

    user || raise(BotError, t[:alias][:not_found] % {alias: escape(_alias)})
  end

  def self.active_users(chat_id)
    where(chat_id: chat_id)
      .exclude(alias: nil)
      .order(:first_name, :last_name)
  end

  def self.real_users(chat_id)
    where(chat_id: chat_id)
      .exclude(user_id: nil, alias: nil)
      .order(:first_name, :last_name)
  end

  def self.virtual_users(chat_id)
    where(chat_id: chat_id, user_id: nil)
      .exclude(alias: nil)
      .order(:first_name, :last_name)
  end

  def self.create_virtual_user(chat_id, name)
    raise BotError, t[:alias][:long_name] if name.length > 32

    _alias = choose_alias(chat_id, name)

    create(
      chat_id:    chat_id,
      alias:      _alias,
      first_name: name
    )
  end

  def self.create_real_user(chat_id, telegram_user)
    if user = Alias[chat_id: chat_id, user_id: telegram_user.id]
      raise BotCancelError,
        t[:alias][:existent] % {full_name: user.full_name}
    end

    _alias = choose_alias(
      chat_id,
      telegram_user.first_name,
      telegram_user.last_name,
      telegram_user.username
    )

    create(
      chat_id:    chat_id,
      user_id:    telegram_user.id,
      alias:      _alias,
      first_name: telegram_user.first_name,
      last_name:  telegram_user.last_name,
      username:   telegram_user.username
    )
  end

  def self.obliterate(chat_id)
    DB.transaction do
      # Deletes transactions as well.
      where(chat_id: chat_id).delete
    end
  end

  def to_real_user(telegram_user)
    if real_user?
      telegram_user_full_name =
        name(telegram_user.first_name, telegram_user.last_name)

      raise BotCancelError, t[:alias][:already_real_user] %
        {real_user_full_name:     full_name,
         telegram_user_full_name: telegram_user_full_name}
    end

    if user = Alias[chat_id: chat_id, user_id: telegram_user.id]
      raise BotCancelError, t[:alias][:already_existent_user] %
        {telegram_user_full_name: user.full_name,
         virtual_user_full_name:  full_name}
    end

    update(
      user_id:    telegram_user.id,
      first_name: telegram_user.first_name,
      last_name:  telegram_user.last_name,
      username:   telegram_user.username
    )
  end

  def to_virtual_user
    if virtual_user?
      raise BotCancelError,
        t[:alias][:already_virtual_user] % {full_name: full_name}
    end

    update(user_id: nil)
  end

  def deactivate
    unless active_user?
      raise BotCancelError,
        t[:alias][:already_inactive_user] % {full_name: full_name}
    end

    if balance.nonzero?
      raise BotCancelError, t[:alias][:non_zero_balance] %
        {full_name: full_name, balance: currency(balance)}
    end

    if transactions.empty?
      delete
    else
      update(alias: nil)
    end
  end

  def full_name(style = BOLD)
    name(first_name, last_name, virtual_user?, self.alias, style)
  end

  def balance
    transactions_dataset.sum(:amount) || BigDecimal(0)
  end

  def self.choose_alias(chat_id, *suggestions)
    recommended = suggestions.compact.map{ |name| name.slice(0).downcase }
    default     = ('a'..'z').to_a
    occupied    = active_users(chat_id).select_map(:alias)

    _alias = ((recommended | default) - occupied).first

    _alias || raise(BotCancelError, t[:alias][:no_aliases_left] %
      {full_name: name(suggestions[0], suggestions[1])}
    )
  end
end
