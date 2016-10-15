class Machine
  def payment_initial_state(msg)
    msg.text =~ /^\/p(?:ago)?\s+(.+)\s*:\s*(.+)\s*/

    if Regexp.last_match # Command with parameters.
      concept = Regexp.last_match[1]
      contributions = Regexp.last_match[2]

      payment = # chat_id, payment_id, date, concept
        Payment.build(@chat_id, msg.message_id, date_helper(msg), concept)

      loop do
        # This separates the first single contribution from the rest.
        contributions.match /^(\S+)(?:\s+(.+))?\s*/

        single_contribution = Regexp.last_match[1]
        # Rest of contributions.
        contributions = Regexp.last_match[2]

        r = /^(\d{0,15}(?:[\.,]\d{1,4})?)
             ([[:alpha:]]+)
             ((?:-(?=[\.,]?\d))?\d{0,15}(?:[\.,]\d{1,4})?)$/x

        single_contribution.match(r)

        if Regexp.last_match.nil?
          raise BotError,
            t[:payment][:argument_error] % {chunk: single_contribution}
        end

        factor  = Regexp.last_match[1]
        _alias  = Regexp.last_match[2]
        contrib = Regexp.last_match[3]

        user = Alias.find_user(@chat_id, _alias)
        payment.contribution(user, contrib)
        payment.factor(user, factor)

        break if contributions.nil?
      end

      payment.save

      render(t[:payment][:success] %
             {concept: payment.concept,
              total:   money_helper(payment.total),
              code:    payment.payment_id})

      :final_state
    else # Step-by-step process.
      if @unequal_split = msg.text.match(/^\/pago_desigual/)
        render(t[:payment][:unequal_payment])
      end

      render(t[:payment][:concept?])

      :payment_concept_state
    end
  end

  def payment_concept_state(msg)
    @payment = # chat_id, payment_id, date, concept
      Payment.build(@chat_id, msg.message_id, date_helper(msg), msg.text)

    @users_kb = one_time_keyboard(
      user_buttons(Alias.active_users(@chat_id))
      .unshift(CREATE_DIALOG_BUTTONS)
    )

    render(t[:payment][:participants?] % {concept: @payment.concept},
           keyboard: @users_kb)

    :payment_user_state
  end

  def payment_user_state(msg)
    if msg.text.match /^guardar/i
      @payment.save

      render(t[:payment][:success] %
             {concept: @payment.concept,
              total:   money_helper(@payment.total),
              code:    @payment.payment_id})

      render(t[:payment][:expert_payment_advice] %
             {concept: @payment.concept, transactions: @payment})

      :final_state
    else
      @user = Alias.find_user(@chat_id, alias_helper(msg))

      render(t[:payment][:contribution?] % {name: @user.first_name},
             keyboard: one_time_keyboard(['Nada']))

      :payment_contribution_state
    end
  end

  def payment_contribution_state(msg)
    c = money_helper(@payment.contribution(@user, msg.text))

    if @unequal_split
      render(t[:payment][:factor?] %
             {name: @user.first_name, contribution: c},
             keyboard: one_time_keyboard([['0', '1', '2', '3']]))

      :payment_factor_state
    else
      render(t[:payment][:next_participant_without_factor?] %
             {name: @user.first_name, contribution: c},
             keyboard: @users_kb)

      :payment_user_state
    end
  end

  def payment_factor_state(msg)
    f = @payment.factor(@user, msg.text)

    render(t[:payment][:next_participant?] %
           {name: @user.first_name, factor: money_helper(f)}, # It's not money
           keyboard: @users_kb)                               # but works as
                                                              # desired.
    :payment_user_state
  end
end
