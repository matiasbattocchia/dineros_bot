class Machine
  def delete_initial_state(msg)
    @date = date_helper(msg)

    msg.text.match /^eliminar(?:_|\s+)([[:digit:]]+)/

    if Regexp.last_match
      code = Regexp.last_match[1]
      @transactions = find_payment(code)

      concept = @transactions.first.concept

      confirmation_kb = Telegram::Bot::Types::ReplyKeyboardMarkup.new(
        keyboard: DIALOG_BUTTONS,
        one_time_keyboard: true,
        selective: true)

      render(t[:delete][:delete_payment?] %
               {concept: concept, code: payment_id},
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
      transaction_amendment(@transactions)
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
