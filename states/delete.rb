class Machine
  def delete_initial_state(msg)
    case msg.text
    when /^\/#{t[:delete]}(?:_|\s+)(?<code>[[:digit:]]+)/i
      @payment = Payment.find(@chat.id, Regexp.last_match[:code])

      text = t[:payment][:amend?] %
        {concept: escape(@payment.concept), code: @payment.payment_id}

      unless private?
        render(
          t[:initial_private_message] % {name: escape(@from.first_name)}
        )

        text += ' (' + escape(@chat.title) + ')'
      end

      render(
        text,
        keyboard: keyboard( [delete_buttons] ),
        private: true
      )

      :delete_payment_confirmation_state

    when /^\/#{t[:delete]}(?:_|\s+)(?<alias>[[:alpha:]]+)/i
      @user = Alias.find_by_alias(@chat.id, Regexp.last_match[:alias])

      text = t[:user][:deactivate?] % {name: @user.name}

      unless private?
        render(
          t[:initial_private_message] % {name: escape(@from.first_name)}
        )

        text += ' (' + escape(@chat.title) + ')'
      end

      render(
        text,
        keyboard: keyboard( [delete_buttons] ),
        private: true
      )

      :delete_user_confirmation_state
    else
      raise BotCancelError, t[:bad_solitude]
    end
  end

  def delete_payment_confirmation_state(msg)
    unless msg.text.match /^#{t[:delete]}/i
      raise BotError, t[:bad_solitude]
    end

    amendment = @payment.amend(msg.message_id, date_helper(msg))

    render(
      t[:final_private_message],
      private: true
    ) unless private?

    render(
      t[:payment][:amended] %
        {concept:        escape(@payment.concept),
         payment_code:   @payment.payment_id,
         amendment_code: amendment.payment_id}
    )

    :final_state
  end

  def delete_user_confirmation_state(msg)
    unless msg.text.match /^#{t[:delete]}/i
      raise BotError, t[:bad_solitude]
    end

    @user.deactivate

    render(
      t[:final_private_message],
      private: true
    ) unless private?

    render(t[:user][:deactivated] % {name: @user.name})

    :final_state
  end
end
