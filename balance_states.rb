class Machine
  def balance_initial_state(msg)
    balance = Transaction.balance(@chat.id).map do |user|
      t[:balance][:item] %
        {name:    name(user[:first_name],
                       nil, # No last name.
                       !user[:user_id], # Not user_id means virtual user.
                       user[:alias],
                       MONO),
         balance: currency(user[:balance] || 0)}
    end

    raise BotCancelError, t[:balance][:no_users] if balance.empty?

    render(balance.join + "\n" + t[:balance][:legend])

    :final_state
  end
end
