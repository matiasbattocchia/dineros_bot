class Machine
  def calculation_initial_state(msg)
    render(t[:calculation][:party_size?])

    :calculation_party_size_state
  end

  def calculation_party_size_state(msg)
    @party_size = msg.text.to_i

    raise BotError, t[:calculation][:small_party] unless @party_size > 2

    @payment = # chat_id, payment_id, date, concept
      Payment.build(@chat_id, msg.message_id, date_helper(msg), :calculation)

    render(t[:calculation][:payers?] % {size: @party_size})

    :calculation_payer_state
  end

  def calculation_payer_state(msg)
    if msg.text.match /^#{t[:calculate]}/i
      @payment.factor(Alias.new(user_id: :others), @others)

      @payment.calculate

      render(@payment.calculation_report)

      :final_state
    else
      @user = pseudouser_helper(msg.text)

      render(t[:calculation][:contribution?] % {name: @user.first_name})

      :calculation_contribution_state
    end
  end

  def calculation_contribution_state(msg)
    c = money_helper(@payment.contribution(@user, msg.text))

    if (@others = @party_size - @payment.total_factor).zero?
      render(t[:calculation][:done] %
             {name: @user.first_name, contribution: c})

      calculation_payer_state(message_helper(t[:calculate]))
    else
      render(t[:calculation][:next_payer?] %
             {name: @user.first_name, contribution: c},
             keyboard: keyboard([calculate_buttons]))

      :calculation_payer_state
    end
  end
end
