class Alias < Sequel::Model
  one_to_many :transactions

  def active_user?
    self.alias
  end

  def self.active_users(chat_id)
    where(chat_id: chat_id)
      .exclude(alias: nil)
      .order(:first_name, :last_name)
  end

  def self.find_by_alias(chat_id, _alias)
    raise BotError, t[:alias][:no_alias] if _alias.nil?

    user = Alias[chat_id: chat_id, alias: _alias]

    user || raise(BotError, t[:alias][:not_found] % {alias: escape(_alias)})
  end

  def created?
    @created
  end

  def self.find_or_create_user(chat_id, name)
    raise BotError, t[:alias][:bad_name] if name !~ /^[[:alpha:]]/
    raise BotError, t[:alias][:long_name] if name.length > 32

    user = where(chat_id: chat_id, first_name: name).exclude(alias: nil).first

    return user if user

    user = create(
      chat_id:    chat_id,
      alias:      choose_alias(chat_id, name),
      first_name: name
    )

    user.instance_variable_set(:@created, true)
    user
  end

  def self.obliterate(chat_id)
    DB.transaction do
      # Deletes transactions as well.
      where(chat_id: chat_id).delete
    end
  end

  def deactivate
    unless active_user?
      raise BotCancelError,
        t[:alias][:already_inactive_user] % {name: name}
    end

    if balance.nonzero?
      raise BotCancelError, t[:alias][:non_zero_balance] %
        {name: name, balance: currency(balance)}
    end

    if transactions.empty?
      delete
    else
      update(alias: nil)
    end
  end

  def name
    escape(first_name)
  end

  def full_name(style = BOLD)
    name(first_name, last_name, self.alias, style)
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
