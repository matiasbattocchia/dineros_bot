class Machine
  def loan_initial_state(msg)
    @active_users = active_users(@chat.id)

    render(t[:loan][:concept?])

    :loan_concept_state
  end

  def loan_concept_state(msg)
    @loan = # chat_id, payment_id, date, concept
      Payment.build(@chat.id, msg.message_id, date_helper(msg), msg.text)

    render(t[:loan][:lender?] % {concept: escape(@loan.concept)},
      keyboard: keyboard( user_buttons(@active_users) )
    )

    :loan_lender_state
  end

  def loan_lender_state(msg)
    @lender = Alias.find_user(@chat.id, alias_helper(msg))

    @active_users.delete(@lender)

    render(t[:loan][:borrower?] % {lender_name: escape(@lender.first_name)},
      keyboard: keyboard( user_buttons(@active_users) )
    )

    :loan_borrower_state
  end

  def loan_borrower_state(msg)
    @borrower = Alias.find_user(@chat.id, alias_helper(msg))

    raise BotError, t[:loan][:borrower_lender] if @borrower == @lender

    render(t[:loan][:contribution?] %
      {borrower_name: escape(@borrower.first_name)}
    )

    :loan_contribution_state
  end

  def loan_contribution_state(msg)
    c = @loan.contribution(@lender, msg.text)

    unless c > 0
      raise BotError,
        t[:loan][:non_positive_contribution] % {contribution: currency(c)}
    end

    @loan.factor(@lender, 0)

    @loan.contribution(@borrower)

    @loan.save

    render(t[:payment][:success] %
      {concept: escape(@loan.concept),
       total:   currency(@loan.total),
       code:    @loan.payment_id}
    )

    render(t[:payment][:expert_payment_advice] %
      {concept: escape(@loan.concept), transactions: @loan}
    )

    :final_state
  end
end
