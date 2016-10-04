class Machine
  def date_helper(msg)
    Time.at(msg.date).utc.to_date
  end

  def find_payment(payment_id)
    transactions =
      Transaction.where(chat_id: @chat_id, payment_id: payment_id)

    if transactions.empty?
      raise BotError,
        t[:helper][:transactions_not_found_error] % {code: payment_id}
    end

    return transactions
  end

  def find_user(_alias)
    user = Alias.find(chat_id: @chat_id, alias: _alias)

    unless user
      raise BotError,
        t[:helper][:user_not_found_error] % {alias: _alias}
    end

    return user
  end

  def alias_helper(msg)
    msg.text.match(/^\(([[:alpha:]]+)\)/)

    if Regexp.last_match.nil?
      raise BotError, t[:helper][:alias_error]
    end

    Regexp.last_match[1]
  end

  def choose_alias(best_aliases)
    occupied_aliases = Alias.where(chat_id: @chat_id).select_map(:alias)
    default_aliases = ('a'..'z').to_a

    _alias = (best_aliases | default_aliases - occupied_aliases).first

    unless _alias
      raise BotError, t[:helper][:no_aliases_left_error]
    end

    return _alias
  end

  def expert_payment_advice
    transactions = @transactions.map do |u, t|
      ("%g" % ("%.2f" % t.factor))
      .to_s
      .sub('.',',')
      .sub(/^1*$/,'') +

      u.alias +

      ("%g" % ("%.2f" % t.contribution))
      .to_s
      .sub('.',',')
      .sub(/^0*$/,'')
    end

    render(t[:helper][:expert_payment_advice] +
           "\n\n/pago #{@concept}:\s" + transactions.join(' '),
           keyboard: HIDE_KB)
  end
end
