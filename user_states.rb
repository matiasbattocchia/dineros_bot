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
    Alias.create_virtual_user(@chat_id, name)
    render(t[:virtual_user][:created])

    :final_state
  end

  def users_initial_state(msg)
    options_kb = Telegram::Bot::Types::ReplyKeyboardMarkup.new(
      keyboard: ['/cancelar',
                 '1. Crear un usuario real',
                 '2. Crear un usuario virtual',
                 '3. Tomar control de un usuario virtual',
                 '4. Eliminar a un usuario'],
      one_time_keyboard: true, selective: true)

    render(t[:user][:option?],
           keyboard: options_kb,
           reply_to: msg)

    :real_user_mentions_state
  end

  def real_user_initial_state(msg)
    render(t[:real_user][:explanation],
           keyboard: FORCE_KB,
           reply_to: msg)

    :real_user_mentions_state
  end

  def real_user_mentions_state(msg)
    users = msg
      .entities
      .select{ |e| e.type =~ /mention/ }
      .map(&:user)

    users.each do |telegram_user|
      Alias.create_real_user(@chat_id, telegram_user)
      render(t[:real_user][:created])
    end

    :final_state
  end
end

    #if result
      #render(t[:alias][:virtual_created] % {name: name, alias: _alias})
    #end

    #return result
  #end


    #if u
      #result = u.update(
        #alias: a,
        #first_name: user.first_name,
        #last_name: user.last_name,
        #username: user.username)

      ## result.nil? means that the record was not updated because
      ## it has not changed, but everything is fine.
      #if result || result.nil?
        #render(t[:alias][:updated] % {name: full_name, alias: _alias})
      #end
    #else

      #if result
        #render(t[:alias][:created] % {name: full_name, alias: _alias})
      #end
    #end

    #return result
