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
              total:   payment.total,
              code:    payment.payment_id})

      :final_state
    else # Step-by-step process.
      if @unequal_split = msg.text.match(/^\/pago_desigual/)
        render(t[:payment][:unequal_payment])
      end

      render(t[:payment][:concept?],
             keyboard: FORCE_KB,
             reply_to: msg)

      :payment_concept_state
    end
  end

  def payment_concept_state(msg)
    @payment = # chat_id, payment_id, date, concept
      Payment.build(@chat_id, msg.message_id, date_helper(msg), msg.text)

    @users_kb = Telegram::Bot::Types::ReplyKeyboardMarkup.new(
      keyboard: user_buttons(@chat_id).unshift(DIALOG_BUTTONS),
      one_time_keyboard: true, selective: true)

    render(t[:payment][:participants?] % {concept: @payment.concept},
           keyboard: @users_kb,
           reply_to: msg)

    :payment_user_state
  end

  def payment_user_state(msg)
    if msg.text.match /^\/confirmar/
      @payment.save

      render(t[:payment][:success] %
             {concept: @payment.concept,
              total:   @payment.total,
              code:    @payment.payment_id},
             keyboard: HIDE_KB)

      render(t[:payment][:expert_payment_advice] %
             {concept: @payment.concept, transactions: @payment})

      :final_state
    else
      @user = Alias.find_user(@chat_id, alias_helper(msg))

      render(t[:payment][:contribution?] % {name: @user.first_name},
             keyboard: FORCE_KB,
             reply_to: msg)

      :payment_contribution_state
    end
  end

  def payment_contribution_state(msg)
    c = @payment.contribution(@user, msg.text)
    c = ("%g" % ("%.2f" % c)).sub('.',',')

    if @unequal_split
      render(t[:payment][:factor?] %
             {name: @user.first_name, contribution: c},
             keyboard: FORCE_KB,
             reply_to: msg)

      :payment_factor_state
    else
      render(t[:payment][:next_participant_without_factor?] %
             {name: @user.first_name, contribution: c},
             keyboard: @users_kb,
             reply_to: msg)

      :payment_user_state
    end
  end

  def payment_factor_state(msg)
    f = @payment.factor(@user, msg.text)
    f = ("%g" % f).sub('.',',')

    render(t[:payment][:next_participant?] %
           {name: @user.first_name, factor: f},
           keyboard: @users_kb,
           reply_to: msg)

    :payment_user_state
  end
end
