class Machine
  def delete_initial_state(msg)
    case msg.text
    when /^\/eliminar(?:_|\s+)([[:digit:]]+)/
      code = Regexp.last_match[1]

      @payment = Payment.find(@chat_id, code)

      render(t[:payment][:amend?] %
             {concept: @payment.concept, code: @payment.payment_id},
             keyboard: one_time_keyboard([DELETE_DIALOG_BUTTONS]))

      :delete_payment_confirmation_status
    when /^\/eliminar(?:_|\s+)([[:alpha:]]+)/
      _alias = Regexp.last_match[1]

      @user = Alias.find_user(@chat_id, _alias)

      render(t[:user][:deactivate?] % {name: @user.full_name},
             keyboard: one_time_keyboard([DELETE_DIALOG_BUTTONS]))

      :delete_user_confirmation_status
    else
      raise BotError, t[:unknown_command]
    end
  end

  def delete_payment_confirmation_status(msg)
    raise BotError, t[:unknown_command] unless msg.text.match(/^eliminar/i)

    amendment = @payment.amend(msg.message_id, date_helper(msg))

    render(t[:payment][:amended] %
           {concept: amendment.concept, code: amendment.payment_id})

    :final_state
  end

  def delete_user_confirmation_status(msg)
    raise BotError, t[:unknown_command] unless msg.text.match(/^eliminar/i)

    @user.deactivate

    render(t[:user][:deactivated])

    :final_state
  end

  #def delete_everything_confirmation_status(msg)
    #raise BotError, t[:unknown_command] if msg.text.match(/^eliminar/i)

    #Alias.obliterate(@chat_id)

    #render(t[:payment][:amended] %
           #{concept: amendment.concept, code: amendment.payment_id})

    #:final_state
  #end
end
