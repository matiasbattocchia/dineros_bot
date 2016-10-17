class Machine
  def loan_initial_state(msg)
    # TODO: "No active users" warning.
    @users_kb = keyboard(
      user_buttons(Alias.active_users(@chat_id))
    )

    render(t[:loan][:concept?])

    :loan_concept_state
  end

  def loan_concept_state(msg)
    @loan = # chat_id, payment_id, date, concept
      Payment.build(@chat_id, msg.message_id, date_helper(msg), msg.text)

    render(t[:loan][:lender?] % {concept: @loan.concept}, keyboard: @users_kb)

    :loan_lender_state
  end

  def loan_lender_state(msg)
    @lender = Alias.find_user(@chat_id, alias_helper(msg))

    render(t[:loan][:borrower?] % {lender_name: @lender.first_name},
           keyboard: @users_kb)

    :loan_borrower_state
  end

  def loan_borrower_state(msg)
    @borrower = Alias.find_user(@chat_id, alias_helper(msg))

    raise BotError, t[:loan][:borrower_lender] if @borrower == @lender

    render(t[:loan][:contribution?] % {borrower_name: @borrower.first_name})

    :loan_contribution_state
  end

  def loan_contribution_state(msg)
    @loan.contribution(@lender, msg.text)
    @loan.factor(@lender, 0)

    @loan.contribution(@borrower)

    @loan.save

    render(t[:payment][:success] %
           {concept: @loan.concept,
            total:   money_helper(@loan.total),
            code:    @loan.payment_id})

    render(t[:payment][:expert_payment_advice] %
           {concept: @loan.concept, transactions: @loan})

    :final_state
  end
end
