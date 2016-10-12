class Machine
  def loan_initial_state(msg)
    transaction_init(msg)

    render(t[:loan][:concept?],
           keyboard: FORCE_KB,
           reply_to: msg)

    :loan_concept_state
  end

  def loan_concept_state(msg)
    @loan = # chat_id, payment_id, date, concept
      Payment.build(@chat_id, msg.message_id, date_helper(msg), msg.text)

    @users_kb = Telegram::Bot::Types::ReplyKeyboardMarkup.new(
      keyboard: user_buttons(@chat_id),
      one_time_keyboard: true, selective: true)

    render(t[:loan][:lender?] % {concept: @loan.concept},
           keyboard: @users_kb,
           reply_to: msg)

    :loan_lender_state
  end

  def loan_lender_state(msg)
    @lender = Alias.find_user(alias_helper(msg))

    render(t[:loan][:borrower?] % {lender_name: @lender.first_name},
           keyboard: @users_kb,
           reply_to: msg)

    :loan_borrower_state
  end

  def loan_borrower_state(msg)
    @borrower = Alias.find_user(alias_helper(msg))

    raise BotError, t[:loan][:borrower_lender] if @borrower == @lender

    render(t[:loan][:contribution?] % {borrower_name: @borrower.first_name},
           keyboard: FORCE_KB,
           reply_to: msg)

    :loan_contribution_state
  end

  def loan_contribution_state(msg)
    @loan.contribution(@lender, msg.text)
    @loan.factor(@lender, 0)

    @loan.contribution(@borrower)

    @loan.save

    render(t[:loan][:success] %
           {concept: @loan.concept,
            total:   @loan.total,
            code:    @loan.payment_id},
           keyboard: HIDE_KB)

    render(t[:payment][:expert_payment_advice] %
           {concept: @loan.concept, transactions: @loan})

    :final_state
  end
end
