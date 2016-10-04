class Machine
  def transaction_init(msg)
    @transactions = Hash.new { |h,k| h[k] = Transaction.new }
    @payment_id   = msg.message_id
    @date         = date_helper(msg)
  end

  def transaction_concept(concept)
    if concept.nil? || concept.empty?
      raise BotError, t[:transaction][:concept_error]
    end

    @concept = concept.downcase
  end

  def transaction_user(user)
    t = @transactions[user]

    t.alias_id     = user.id
    t.chat_id      = @chat_id
    t.payment_id   = @payment_id
    t.date         = @date
    t.concept      = @concept
    t.amendment    = false
    t.contribution = BigDecimal(0)
    t.factor       = BigDecimal(1)

    return t
  end

  def transaction_contribution(user, contribution)
    t = @transactions[user]

    t.contribution = BigDecimal(contribution.sub(',','.'))

    return t
  end

  def transaction_factor(user, factor)
    t = @transactions[user]

    factor = BigDecimal(factor.sub(',','.'))

    if factor.negative?
      raise BotError, t[:transaction][:factor_error]
    end

    t.factor = factor

    return t
  end

  def transaction_save
    if @transactions.empty?
      raise BotError, t[:transaction][:save_error]
    end

    contribution_sum = 0
    factor_sum = 0

    @transactions.each do |_, t|
      contribution_sum += t.contribution
      factor_sum += t.factor
    end

    DB.transaction do
      @transactions.each do |_, t|
        co_contribution =
          contribution_sum / factor_sum * t.factor

        t.amount = t.contribution - co_contribution
        t.save
      end
    end

    render(t[:transaction][:success] %
           {concept: @concept, code: @payment_id})

    return true
  end

  def transaction_amendment(transactions)
    concept = transactions.first.concept

    corrections = []

    transactions.each do |t|
      if t.amendment
        raise BotError, t[:transaction][:already_amended_error] %
          {concept: concept, code: payment_id}
      end

      # We copy each transaction...
      c = Transaction.new
      c.alias_id     = t.alias_id
      c.chat_id      = t.chat_id
      c.payment_id   = t.payment_id
      c.concept      = t.concept
      c.contribution = t.contribution
      c.factor       = t.factor

      # with some differences: actual date,
      # marked as an amendment and negated amount.
      c.date      = @date
      c.amendment = true
      c.amount    = -t.amount

      # So these new transactions cancel out with
      # the original ones.
    end

    DB.transaction do
      corrections.each(&:save)
    end

    render(t[:transaction][:amended] % {concept: concept, code: payment_id}

    return true
  end
end
