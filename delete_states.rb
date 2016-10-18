class Machine
  def delete_initial_state(msg)
    case msg.text
    when /^\/eliminar(?:_|\s+)([[:digit:]]+)/
      code = Regexp.last_match[1]

      @payment = Payment.find(@chat_id, code)

      render(t[:payment][:amend?] %
             {concept: @payment.concept, code: @payment.payment_id},
             keyboard: keyboard([delete_buttons]))

      :delete_payment_confirmation_status
    when /^\/eliminar(?:_|\s+)([[:alpha:]]+)/
      _alias = Regexp.last_match[1]

      @user = Alias.find_user(@chat_id, _alias)

      render(t[:user][:deactivate?] % {name: @user.full_name},
             keyboard: keyboard([delete_buttons]))

      :delete_user_confirmation_status
    else
      raise BotError, t[:unknown_command]
    end
  end

  def delete_payment_confirmation_status(msg)
    unless msg.text.match /^#{t[:delete]}/i
      raise BotError, t[:unknown_command]
    end

    amendment = @payment.amend(msg.message_id, date_helper(msg))

    render(t[:payment][:amended] %
           {concept: amendment.concept, code: amendment.payment_id})

    :final_state
  end

  def delete_user_confirmation_status(msg)
    unless msg.text.match /^#{t[:delete]}/i
      raise BotError, t[:unknown_command]
    end

    @user.deactivate

    render(t[:user][:deactivated])

    :final_state
  end
end