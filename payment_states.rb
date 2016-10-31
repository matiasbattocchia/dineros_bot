class Machine
  def payment_initial_state(msg)
    set_originator(msg)

    arguments =
      msg.text.match(/^\/p\s+(?<concept>.+)\s*:\s*(?<contributions>.+)\s*/i)

    if arguments # Command with arguments.
      expert_payment(msg, arguments[:concept], arguments[:contributions])

      :final_state
    else # Step-by-step process.
      @active_users = active_users(@chat.id)
      @existent_users = @active_users.any?

      if @unequal_split = msg.text.match(/^\/#{t[:unequal_split]}/i)
        render(t[:payment][:unequal_payment])
      end

      render(t[:payment][:concept?], keyboard: keyboard(t[:cancel_payment]))

      :payment_concept_state
    end
  end

  def payment_concept_state(msg)
    @payment = # chat_id, payment_id, date, concept
      Payment.build(@chat.id, msg.message_id, date_helper(msg), msg.text)

    #render(t[:payment][:payment_advice]) unless @unequal_split

    render(t[:payment][:participants?] % {concept: escape(@payment.concept)},
      keyboard: keyboard( user_buttons(@active_users) << t[:cancel_payment] )
    )

    :payment_user_state
  end

  def payment_user_state(msg)
    if msg.text.match /^#{t[:save]}/i
      @payment.save

      render(t[:payment][:success] %
        {concept: escape(@payment.concept),
         total:   currency(@payment.total),
         code:    @payment.payment_id,
         report:  @payment.report}
      )

      #render(t[:payment][:expert_payment_advice] %
        #{concept: escape(@payment.concept), transactions: @payment}
      #)

      :final_state
    else
      @user = Alias.find_or_create_user(@chat.id, msg.text)

      @active_users.delete(@user)

      if @payment[@user]
        render(t[:payment][:correction] % {name: @user.name},
          keyboard: keyboard( [t[:nothing], t[:cancel_payment]] )
        )
      else
        render(t[:payment][:contribution?] % {name: @user.name},
          keyboard: keyboard( [t[:nothing], t[:cancel_payment]] )
        )
      end

      :payment_contribution_state
    end
  end

  def payment_contribution_state(msg)
    c = @payment.contribution(@user, msg.text)

    render(t[:payment][:negative_contribution]) if c.negative?

    c = currency(c)

    if @unequal_split
      render(t[:payment][:factor?] %
        {name: @user.name, contribution: c},
        keyboard: keyboard( [['0', '1', '2', '3'], t[:cancel_payment]] )
      )

      :payment_factor_state
    else
      #if @existent_users && @active_users.empty?
        #render(t[:payment][:done_without_factor] %
          #{name: @user.name, contribution: c}
        #)

        #payment_user_state(message_helper(t[:save]))
      #else
        render(t[:payment][:next_participant_without_factor?] %
          {name: @user.name, contribution: c},
          keyboard: keyboard( user_buttons(@active_users) << create_buttons )
        )

        :payment_user_state
      #end
    end
  end

  def payment_factor_state(msg)
    f = number(@payment.factor(@user, msg.text))

    #if @existent_users && @active_users.empty?
      #render(t[:payment][:done] % {name: @user.name, factor: f})

      #payment_user_state(message_helper(t[:save]))
    #else
      render(t[:payment][:next_participant?] % {name: @user.name, factor: f},
        keyboard: keyboard( user_buttons(@active_users) << create_buttons )
      )

      :payment_user_state
    #end
  end

  def expert_payment(msg, concept, contributions)
    payment = # chat_id, payment_id, date, concept
      Payment.build(@chat.id, msg.message_id, date_helper(msg), concept)

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
        raise BotCancelError,
          t[:payment][:argument_error] % {chunk: single_contribution}
      end

      factor  = Regexp.last_match[1]
      _alias  = Regexp.last_match[2]
      contrib = Regexp.last_match[3]

      factor  = 1 if factor.empty?
      contrib = 0 if contrib.empty?

      user = Alias.find_by_alias(@chat.id, _alias)

      if payment[user]
        raise BotCancelError,
          t[:payment][:repeated_user] % {alias: user.alias}
      end

      payment.contribution(user, contrib)
      payment.factor(user, factor)

      break if contributions.nil?
    end

    payment.save

    render(
      t[:payment][:success] %
        {concept: escape(payment.concept),
         total:   currency(payment.total),
         code:    payment.payment_id,
         report:  payment.report}
    )
  end

  def explain_initial_state(msg)
    if msg.text =~ /^\/#{t[:explain_command]}(?:_|\s+)(?<code>[[:digit:]]+)/i
      @payment = Payment.find(@chat.id, Regexp.last_match[:code])

      render(@payment.explain)

      :final_state
    else
      raise BotError, t[:unknown_command]
    end
  end
end
