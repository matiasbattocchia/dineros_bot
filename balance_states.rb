class Machine
  def balance_initial_state(msg)
    balance = Transaction.balance(@chat_id).map do |user|
      t[:balance][:item] %
        {alias:   user[:alias],
         name:    name_helper(user[:first_name],
                              nil, # No last name.
                              user[:user_id]),
         balance: money_with_cents_helper(user[:balance] || 0)}
    end

    raise BotError, t[:balance][:no_users] if balance.empty?

    render(balance.join("\n") + "\n\n" + t[:balance][:legend])

    :final_state
  end
end
