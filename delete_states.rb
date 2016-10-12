class Machine
  def delete_initial_state(msg)
    msg.text.match /^\/eliminar(?:_|\s+)([[:digit:]]+)/

    if Regexp.last_match
      code = Regexp.last_match[1]
      @payment = Payment.find(@chat_id, code)

      confirmation_kb = Telegram::Bot::Types::ReplyKeyboardMarkup.new(
        keyboard: [DIALOG_BUTTONS],
        one_time_keyboard: true,
        selective: true)

      render(t[:payment][:amend?] %
             {concept: @payment.concept, code: @payment.payment_id},
             keyboard: confirmation_kb,
             reply_to: msg)

      :delete_confirmation_status
    else
      render(t[:delete][:what?],
             #keyboard: DELETEABLES,
             reply_to: msg)

      :delete_option_state
    end
  end

  def delete_confirmation_status(msg)
    if msg.text.match /^\/confirmar/
      amendment = @payment.amend(msg.message_id, date_helper(msg))

      render(t[:payment][:amended] %
             {concept: amendment.concept, code: amendment.payment_id})

      :final_state
    else
      raise BotError, t[:unknown_command]
    end
  end

  def delete_option_state(msg)
    case msg.text
    when /usuario/i

      :delete_user_state
    when /todo/i

      :delete_everything_state
    else
      raise BotError, t[:delete][:option_error]
    end
  end

  def delete_code_state(msg)
    if msg.text !~ /^[[:digit:]]+$/
      raise BotError, 'El código de la operación tiene que ser un número.'
    end

    payment_correction(msg.text)

    :final_state
  end
end
