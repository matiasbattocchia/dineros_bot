class Machine
  def delete_initial_state(msg)
    set_originator(msg)

    case msg.text
    when /^\/#{t[:delete]}(?:_|\s+)(?<code>[[:digit:]]+)/i
      @payment = Payment.find(@chat.id, Regexp.last_match[:code])

      render(t[:payment][:amend?] %
        {concept: escape(@payment.concept), code: @payment.payment_id},
        keyboard: keyboard( [delete_buttons] )
      )

      :delete_payment_confirmation_state

    when /^\/#{t[:delete]}(?:_|\s+)(?<alias>[[:alpha:]]+)/i
      @user = Alias.find_by_alias(@chat.id, Regexp.last_match[:alias])

      render(t[:user][:deactivate?] % {name: @user.name},
        keyboard: keyboard( [delete_buttons] )
      )

      :delete_user_confirmation_state
    else
      raise BotError, t[:unknown_command]
    end
  end

  def delete_payment_confirmation_state(msg)
    unless msg.text.match /^#{t[:delete]}/i
      raise BotError, t[:unknown_command]
    end

    amendment = @payment.amend(msg.message_id, date_helper(msg))

    render(t[:payment][:amended] %
      {concept:        escape(@payment.concept),
       payment_code:   @payment.payment_id,
       amendment_code: amendment.payment_id}
    )

    :final_state
  end

  def delete_user_confirmation_state(msg)
    unless msg.text.match /^#{t[:delete]}/i
      raise BotError, t[:unknown_command]
    end

    @user.deactivate

    render(t[:user][:deactivated] % {name: @user.name})

    :final_state
  end
end
