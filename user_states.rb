class Machine
  def users_initial_state(msg)
    user_list = Transaction.balance(@chat.id).map do |user|
      full_name = name(
        user[:first_name],
        user[:last_name],
        user[:alias],
        MONO
      )

      if (user[:balance] || 0).zero?
        t[:user][:deletable_item] %
          {full_name: full_name, alias: user[:alias]}
      else
        t[:user][:undeletable_item] %
          {full_name: full_name, balance: currency(user[:balance])}
      end
    end

    raise BotCancelError, t[:user][:no_users] if user_list.empty?

    render(user_list.join("\n") + "\n" + t[:user][:delete_legend])

    :final_state
  end
end
