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
      raise BotCancelError, t[:payment][:not_found] % {code: payment_id}
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

  def [](user)
    @transactions.fetch(user, nil)
  end

  def size
    @transactions.size
  end

  def empty?
    @transactions.empty?
  end

  def contribution(user, contribution = 0)
    contribution.sub!(',','.') if contribution.is_a?(String)

    contribution =
      begin
        BigDecimal(contribution)
      rescue ArgumentError
        BigDecimal(0)
      end

    raise BotError, t[:payment][:nan_contribution] unless contribution.finite?

    t = @transactions[user]
    t.contribution = contribution
  end

  def factor(user, factor = 1)
    factor.sub!(',','.') if factor.is_a?(String)

    factor =
      begin
        BigDecimal(factor)
      rescue ArgumentError
        BigDecimal(1)
      end

    raise BotError, t[:payment][:nan_factor] unless factor.finite?
    raise BotError, t[:payment][:negative_factor] if factor.negative?

    t = @transactions[user]
    t.factor = factor
  end

  def total_contribution
    @transactions.values.map(&:contribution).reduce(:+) || BigDecimal(0)
  end
  alias total total_contribution

  def total_factor
    @transactions.values.map(&:factor).reduce(:+) || BigDecimal(0)
  end

  def calculate(party_size = nil)
    if party_size
      @transactions.delete_if do |_, t|
        t.contribution.zero?
      end

      if @transactions.empty?
        raise BotCancelError, t[:calculation][:null_total_contribution]
      end

      others = party_size - total_factor

      if others.zero?
        c = @transactions.values.map(&:contribution).sort

        if c.first == c.last
          raise BotCancelError, t[:calculation][:evenly_split]
        end
      else
        factor(Alias.new(user_id: :others), others)
      end
    end

    average_contribution = total_contribution / total_factor

    unless average_contribution.finite?
      raise BotCancelError, t[:payment][:null_total_factor]
    end

    @transactions.delete_if do |_, t|
      t.contribution.zero? && t.factor.zero?
    end

    @transactions.each do |_, t|
      t.amount = t.contribution - average_contribution * t.factor
    end
  end

  def save
    if Transaction[chat_id: @chat_id, payment_id: @payment_id]
      raise BotCancelError, t[:payment][:existent] %
        {concept: escape(@concept), code: @payment_id}
    end

    if @transactions.size == 1
      transaction_user = @transactions.values.first.alias

      Alias.active_users(@chat_id)
        .exclude(alias: transaction_user.alias)
        .each{ |user| contribution(user) }
    end

    calculate

    if @transactions.empty?
      raise BotCancelError, t[:payment][:no_transactions]
    end

    if @transactions.size == 1
      raise BotCancelError, t[:payment][:single_transaction]
    end

    unless @transactions.find{ |_, t| t.contribution.nonzero? }
      raise BotCancelError, t[:payment][:no_contributions]
    end

    DB.transaction do
      @transactions.values.each(&:save)
    end

    self
  end

  def amend(amendment_id, date)
    if Transaction[chat_id: @chat_id, amended_payment_id: @payment_id]
      raise BotCancelError, t[:payment][:already_amended] %
        {concept: escape(@concept), code: @payment_id}
    end

    amendments = {}

    @transactions.each do |u, t|
      unless u.active_user?
        raise BotCancelError, t[:payment][:inactive_user] %
          {concept:   escape(@concept),
           code:      @payment_id,
           full_name: u.full_name}
      end

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
      currency(t.factor)
      .sub(/^1$/,'') +

      u.alias +

      currency(t.contribution)
      .sub(/^0+$/,'')
    end.join(' ')
  end

  def report
    @transactions.map do |u, t|
      line = ['*•* ']
      line << currency(t.factor) + ' × ' unless t.factor == 1
      line << u.name
      line << ': ' + currency(t.contribution) unless t.contribution == 0
      line.join
    end.join("\n")
  end

  def explain
    report = []

    c = @transactions.values.map(&:factor).sort

    if c.first == c.last # Equal split.
      report << t[:explain][:equal_split][:header] %
        {concept: concept,
         total: currency(total),
         party_size: size,
         individual_expenditure: currency(total / size)}

      report << @transactions.map do |u, tr|
        if tr.amount.positive?
          t[:explain][:equal_split][:positive_item]
        elsif tr.amount.zero?
          t[:explain][:equal_split][:zero_item]
        else # Negative.
          t[:explain][:equal_split][:negative_item]
        end % {name: u.name,
               contribution: currency(tr.contribution),
               amount: currency(tr.amount.abs)}
      end.join("\n")
    else # Unequal split.
      unitary_expenditure = total / total_factor

      report << t[:explain][:unequal_split][:header] %
        {concept: concept,
         total: currency(total),
         total_factor: currency(total_factor),
         unitary_expenditure: currency(unitary_expenditure)}

      report << @transactions.map do |u, tr|
        if tr.amount.positive?
          t[:explain][:unequal_split][:positive_item]
        elsif tr.amount.zero?
          t[:explain][:unequal_split][:zero_item]
        else # Negative.
          t[:explain][:unequal_split][:negative_item]
        end % {name: u.name,
               contribution: currency(tr.contribution),
               amount: currency(tr.amount.abs),
               expenditure: currency(unitary_expenditure * tr.factor),
               factor: currency(tr.factor)}
      end.join("\n")
    end

    report.join("\n")
  end

  def calculation_report
    report = []

    header = t[:calculation][:report_header] %
      {total: currency(total), party_size: total_factor.to_i}

    report << header

    groups = @transactions.group_by{ |u, t| u.user_id || t.amount.sign }

    creditors = groups[BigDecimal::SIGN_POSITIVE_FINITE]&.map do |pair|
      t[:calculation][:report_item] %
        {name:   escape(pair.first.first_name),
         amount: currency(pair.last.amount)}
    end

    debt = groups[BigDecimal::SIGN_POSITIVE_FINITE]&.reduce(0) do |sum, pair|
      sum + pair.last.amount
    end || 0

    # Creditors are always present.
    report << creditors.unshift(t[:calculation][:report_creditors]).join

    evens = groups[BigDecimal::SIGN_POSITIVE_ZERO]&.map do |pair|
      t[:calculation][:report_even_item] %
        {name: escape(pair.first.first_name)}
    end

    if evens
      report << evens.unshift(t[:calculation][:report_evens]).join
    end

    debtors = groups[BigDecimal::SIGN_NEGATIVE_FINITE]&.map do |pair|
      t[:calculation][:report_item] %
        {name:   escape(pair.first.first_name),
         amount: currency(-pair.last.amount)}
    end

    if debtors
      report << debtors.unshift(t[:calculation][:report_debtors]).join
    end

    if others = groups[:others]&.first&.last
      if others.factor == 1
        report << t[:calculation][:report_others_singular] %
          {amount: currency(-others.amount)}
      else
        report << t[:calculation][:report_others_plural] %
          {others_size: others.factor.to_i,
           amount: currency(-others.amount / others.factor)}
      end
    end

    number_of_debtors = groups[BigDecimal::SIGN_NEGATIVE_FINITE]&.size || 0
    number_of_others  = others&.factor || 0

    unless number_of_debtors + number_of_others == 1
      footer = t[:calculation][:report_footer] %
        {to_collect: currency(debt)}

      report << footer
    end

    report.join("\n")
  end
end
