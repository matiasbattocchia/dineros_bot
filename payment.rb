class Transaction < Sequel::Model
  many_to_one :alias

  def self.balance(chat_id)
    right_join(Alias.active_users(chat_id), :id=>:alias_id)
      .select_group(:user_id, :alias, :first_name, :last_name)
      .select_append{sum(:amount).as(:balance)}.order(:first_name)
      .map(&:values)
  end
end

class Payment
  def self.find(chat_id, payment_id)
    transactions = {}

    Transaction
      .where(chat_id: chat_id, payment_id: payment_id)
      .each do |t|
      # Calling #alias is a DB hit per transaction.
      transactions[t.alias] = t
    end

    if transactions.empty?
      raise BotError, t[:payment][:not_found] % {code: payment_id}
    end

    new(transactions, chat_id, payment_id,
        transactions.values.first.date,
        transactions.values.first.concept)
  end

  def self.build(chat_id, payment_id, date, concept)
    raise BotError, t[:payment][:empty_concept] if concept.empty?
    raise BotError, t[:payment][:long_concept]  if concept.length > 32

    concept.downcase!

    transactions = Hash.new do |hash, key| # The key is an alias.
      t = Transaction.new

      t.alias_id     = key.id
      t.chat_id      = chat_id
      t.payment_id   = payment_id
      t.date         = date
      t.concept      = concept
      t.contribution = BigDecimal(0)
      t.factor       = BigDecimal(1)

      hash[key] = t
    end

    new(transactions, chat_id, payment_id, date, concept)
  end

  attr_reader :chat_id, :payment_id, :date, :concept

  def initialize(transactions, chat_id, payment_id, date, concept)
    @transactions = transactions
    @chat_id      = chat_id
    @payment_id   = payment_id
    @date         = date
    @concept      = concept
  end

  def contribution(user, contribution = 0)
    contribution.sub!(',','.') if contribution.is_a?(String)
    t = @transactions[user]
    t.contribution = BigDecimal(contribution)
  end

  def factor(user, factor = 1)
    if factor.is_a?(String)
      factor = factor.empty? ? 1 : factor.sub(',','.')
    end

    factor = BigDecimal(factor)
    t = @transactions[user]

    raise BotError, t[:payment][:negative_factor] if factor.negative?

    t.factor = factor
  end

  def total_contribution
    @transactions.values.map(&:contribution).reduce(:+)
  end
  alias total total_contribution

  def total_factor
    @transactions.values.map(&:factor).reduce(:+)
  end

  def save
    raise BotError, t[:payment][:no_transactions] if @transactions.empty?

    if Transaction[chat_id: @chat_id, payment_id: @payment_id]
      raise BotError,
        t[:payment][:existent] % {concept: @concept, code: @payment_id}
    end

    if @transactions.size == 1
      transaction_user = @transactions.values.first.alias

      Alias.active_users(@chat_id)
        .exclude(alias: transaction_user.alias)
        .each{ |user| contribution(user) }
    end

    if @transactions.size == 1
      raise BotError, t[:payment][:single_transaction]
    end

    average_contribution = total_contribution / total_factor

    DB.transaction do
      @transactions.each do |_, t|
        t.amount = t.contribution - average_contribution * t.factor
        t.save
      end
    end

    self
  end

  def amend(amendment_id, date)
    if Transaction[chat_id: @chat_id, amended_payment_id: @payment_id]
      raise BotError, t[:payment][:already_amended] %
        {concept: @concept, code: @payment_id}
    end

    amendments = {}

    @transactions.each do |u, t|
      # We copy each transaction...
      a = Transaction.new
      a.alias_id = t.alias_id
      a.chat_id  = t.chat_id
      a.concept  = t.concept
      a.factor   = t.factor
      # with some differences,
      a.payment_id         = amendment_id
      a.amended_payment_id = @payment_id
      a.date               = date
      a.contribution       = -t.contribution
      # so these new transactions cancel out with
      # the original ones.

      amendments[u] = a
    end

    # transactions, chat_id, payment_id, date, concept
    Payment.new(amendments, @chat_id, amendment_id, date, @concept).save
  end

  def to_s
    @transactions.map do |u, t|
      money_helper(t.factor)
      .sub(/^1*$/,'') +

      u.alias +

      money_helper(t.contribution)
      .sub(/^0*$/,'')
    end.join(' ')
  end
end
