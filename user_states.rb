class Machine
  def virtual_user_initial_state(msg)
    render(t[:virtual_user][:name?],
      keyboard: FORCE_KB,
      reply_to: msg)

    :virtual_user_name_state
  end

  def virtual_user_name_state(msg)
    msg.text.match /^([[:alpha:]][[:print:]]*)/

    if Regexp.last_match.nil?
      raise BotError, t[:virtual_user][:name_error]
    end

    name = Regexp.last_match[1]
    create_virtual_alias(name)

    :final_state
  end
end
