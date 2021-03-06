class Machine
  def loan_initial_state(msg)
    @active_users = active_users(@chat.id)

    text = t[:loan][:concept?]

    unless private?
      render(
        t[:initial_private_message] % {name: escape(@from.first_name)}
      )

      text += ' (' + escape(@chat.title) + ')'
    end

    render(
      text,
      keyboard: keyboard(t[:cancel_loan]),
      private: true
    )

    :loan_concept_state
  end

  def loan_concept_state(msg)
    @loan = # chat_id, payment_id, date, concept
      Payment.build(@chat.id, msg.message_id, date_helper(msg), msg.text)

    render(
      t[:loan][:lender?] % {concept: escape(@loan.concept)},
      keyboard: keyboard( user_buttons(@active_users) << t[:cancel_loan] ),
      private: true
    )

    :loan_lender_state
  end

  def loan_lender_state(msg)
    @lender = Alias.find_or_create_user(@chat.id, msg.text)

    @active_users.delete(@lender)

    #if @active_users.size == 1
      #loan_borrower_state(
        #message_helper( user_buttons(@active_users).first )
      #)
    #else
      render(
        t[:loan][:borrower?] % {lender_name: @lender.name},
        keyboard: keyboard( user_buttons(@active_users) << t[:cancel_loan] ),
        private: true
      )

      :loan_borrower_state
    #end
  end

  def loan_borrower_state(msg)
    @borrower = Alias.find_or_create_user(@chat.id, msg.text)

    raise BotError, t[:loan][:borrower_lender] if @borrower == @lender

    render(
      t[:loan][:contribution?] % {borrower_name: @borrower.name},
      keyboard: keyboard(t[:cancel_loan]),
      private: true
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

    render(
      t[:final_private_message],
      private: true
    ) unless private?

    render(t[:loan][:success] %
      {concept:  escape(@loan.concept),
       total:    currency(@loan.total),
       code:     @loan.payment_id,
       lender:   @lender.name,
       borrower: @borrower.name}
    )

    #render(t[:payment][:expert_payment_advice] %
      #{concept: escape(@loan.concept), transactions: @loan}
    #)

    :final_state
  end
end
