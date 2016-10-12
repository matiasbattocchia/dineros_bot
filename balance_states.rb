class Machine
  def balance_initial_state(msg)
    balance = Transaction
      .right_join(Alias.active_users(@chat_id), :id=>:alias_id)
      .select_group(:alias, :first_name)
      .select_append{sum(:amount).as(:balance)}.order(:first_name)
      .map(&:values).map do |a|
        (t[:balance][:item] %
          {alias:   a[:alias],
           name:    a[:first_name],
           balance: a[:balance] || 0})
        .sub('.',',')
    end.join("\n")

    raise BotError, t[:balance][:no_users] if balance.empty?

    render(balance)

    :final_state
  end
end
