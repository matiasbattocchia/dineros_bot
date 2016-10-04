def payment_initial_state(msg)
  transaction_init(msg)

  msg.text =~ /^\/p(ago)?\s+(.+)\s*:\s*(.+)\s*/

  if Regexp.last_match
    # Command with parameters.

    transaction_concept(Regexp.last_match[1])
    contributions = Regexp.last_match[2]

    loop do
      # This separates the first single contribution from the rest.
      contributions.match /^(\S+)(?:\s+(.+))?\s*/

      # Single contribution.
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

      @user = find_user(_alias)
      transaction_user(@user)
      transaction_contribution(@user, contrib)
      transaction_factor(@user, factor)

      break if contributions.nil?
    end

    transaction_save

    :final_state
  else
    # Step-by-step process.

    @unequal_split =
      if msg.text.match /^\/pago_desigual/
        render(t[:payment][:unequal_payment_explanation])
        true
      else
        false
      end

    render(t[:payment][:concept?],
           keyboard: FORCE_KB,
           reply_to: msg)

    :payment_concept_state
  end
end

def payment_concept_state(msg)
  transaction_concept(msg.text)

  user_names = Alias.where(chat_id: @chat_id).map do |a|
    ['(' + a.alias + ')', a.first_name, a.last_name].join(' ')
  end

  user_names.unshift DIALOG_BUTTONS

  @users_kb = Telegram::Bot::Types::ReplyKeyboardMarkup
    .new(keyboard: user_names, one_time_keyboard: true, selective: true)

  render(t[:payment][:participants?] % {concept: @concept},
         keyboard: @users_kb,
         reply_to: msg)

  :payment_user_state
end

def payment_user_state(msg)
  if msg.text.match /^\/confirmar/
    transaction_save

    expert_payment_advice

    :final_state
  else
    @user = find_user(alias_helper(msg))
    transaction_user(@user)

    render(t[:payment][:contribution?] % {name: @user.first_name},
           keyboard: FORCE_KB,
           reply_to: msg)

    :payment_contribution_state
  end
end

def payment_contribution_state(msg)
  t = transaction_contribution(@user, msg.text)
  c = ("%g" % "%.2f" % t.contribution).sub('.',',')

  if @unequal_split
    render(t[:payment][:factor?] %
             {name: @user.first_name, contribution: c},
           keyboard: FORCE_KB,
           reply_to: msg)

    :payment_factor_state
  else
    render(t[:payment][:next_participant_skip_factor?] %
             {name: @user.first_name, contribution: c},
           keyboard: @users_kb,
           reply_to: msg)

    :payment_user_state
  end
end

def payment_factor_state(msg)
  t = payment_transaction_factor(@user, msg.text)
  f = ("%g" % t.factor).sub('.',',')

  render(t[:payment][:next_participant?] %
           {name: @user.first_name, factor: f},
         keyboard: @users_kb,
         reply_to: msg)

  :payment_user_state
end
