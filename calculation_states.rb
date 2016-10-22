class Machine
  def calculation_initial_state(msg)
    render(t[:calculation][:party_size?])

    :calculation_party_size_state
  end

  def calculation_party_size_state(msg)
    @party_size = msg.text.to_i

    raise BotError, t[:calculation][:small_party] unless @party_size > 2

    @payment = # chat_id, payment_id, date, concept
      Payment.build(@chat.id, msg.message_id, date_helper(msg), 'calculation')

    render(t[:calculation][:payers?] % {size: @party_size})

    :calculation_payer_state
  end

  def calculation_payer_state(msg)
    if msg.text.match /^#{t[:calculate]}/i
      @payment.factor(Alias.new(user_id: :others), @others) if @others > 0

      @payment.calculate

      render(@payment.calculation_report)

      :final_state
    else
      msg.text.match(
        /^(?<name>[[[:alpha:]][[:space:]]]+)(?<amount>[[[:digit:]],.]+)?/
      )

      @user = pseudouser_helper(Regexp.last_match[:name].strip)

      if @payment[@user]
        raise BotError,
          t[:calculation][:repeated_user] % {name: escape(@user.first_name)}
      end

      raise BotCancelError, t[:calculation][:user_limit] if @payment.size > 26

      if Regexp.last_match(:amount)
        calculation_contribution_state(Regexp.last_match[:amount])
      else
        render(t[:calculation][:contribution?] %
          {name: escape(@user.first_name)}
        )

        :calculation_contribution_state
      end
    end
  end

  def calculation_contribution_state(msg)
    c = currency(@payment.contribution(@user, msg.text))

    if (@others = @party_size - @payment.total_factor).zero?
      render(t[:calculation][:done] %
        {name: escape(@user.first_name), contribution: c}
      )

      calculation_payer_state(message_helper(t[:calculate]))
    else
      render(t[:calculation][:next_payer?] %
        {name: escape(@user.first_name), contribution: c},
        keyboard: keyboard( [calculate_buttons] )
      )

      :calculation_payer_state
    end
  end
end
