class Machine
  def balance_initial_state(msg)
    balance = Transaction
      .right_join(Alias.where(chat_id: @chat_id), :id=>:alias_id)
      .select_group(:alias, :first_name)
      .select_append{sum(:amount).as(:balance)}.order(:first_name)
      .map(&:values).map do |a|
        (t[:balance][:item] %
          {alias:   a[:alias],
           user:    a[:first_name],
           balance: a[:balance] || 0})
        .sub('.',',')
    end.join("\n")

    if balance.empty?
      raise BotError, t[:balance][:no_users]
    end

    render(balance)
    :final_state
  end
end
