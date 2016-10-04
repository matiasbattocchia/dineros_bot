class Machine
  def loan_initial_state(msg)
    transaction_init(msg)

    render(t[:loan][:concept?].
           keyboard: FORCE_KB,
           reply_to: msg)

    :loan_concept_state
  end

  def loan_concept_state(msg)
    transaction_concept(msg.text)

    user_names = Alias.where(chat_id: @chat_id).map { |a|
      ['(' + a.alias + ')', a.first_name, a.last_name].join(' ')
    }

    @users_kb = Telegram::Bot::Types::ReplyKeyboardMarkup
      .new(keyboard: user_names, one_time_keyboard: true, selective: true)

    render(t[:loan][:lender?] % {concept: @concept},
           keyboard: @users_kb,
           reply_to: msg)

    :loan_lender_state
  end

  def loan_lender_state(msg)
    @lender = find_user(alias_helper(msg))
    transaction_user(@lender)

    render(t[:loan][:borrower?] % {lender_name: @lender.first_name},
           keyboard: @users_kb,
           reply_to: msg)

    :loan_borrower_state
  end

  def loan_borrower_state(msg)
    @borrower = find_user(alias_helper(msg))

    if @borrower == @lender
      raise BotError, t[:loan][:borrower_lender_error]
    end

    transaction_user(@lender)

    render(t[:loan][:contribution?] % {borrower_name: @borrower.first_name},
           keyboard: FORCE_KB,
           reply_to: msg)

    :loan_contribution_state
  end

  def loan_contribution_state(msg)
    transaction_contribution(@lender, msg.text)
    transaction_factor(@lender, 0)
    transaction_save

    expert_payment_advice

    :final_state
  end
end
