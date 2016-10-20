class Machine
  def users_initial_state(msg)
    if @first_time = msg.text.match(/^\/usuarios_inicial/)
      real_user_initial_state(msg)
    else
      render(t[:user][:option?],
        keyboard: keyboard([t[:cancel]] + t[:user][:menu]))

      :users_options_state
    end
  end

  def users_options_state(msg)
    case msg.text.slice(0).to_i
    when 1 then real_user_initial_state(msg)
    when 2 then virtual_user_initial_state(msg)
    when 3 then virtual_to_real_user_initial_state(msg)
    when 4 then delete_user_initial_state(msg)
    else
      raise BotError, t[:unknown_command]
    end
  end

  def real_user_initial_state(msg)
    render(t[:real_user][:mentions?])

    :real_user_mentions_state
  end

  def real_user_mentions_state(msg)
    mentions = msg
      .entities
      .select{ |e| e.type =~ /mention/ }

    if self_mention = self_mention_helper(msg)
      mentions << self_mention
    end

    raise BotError, t[:real_user][:no_mentions] if mentions.empty?

    mentions.each do |mention|
      mention_text = msg.text.slice(mention.offset, mention.length)

      if telegram_user = mention.user
        if user = Alias[chat_id: @chat.id, user_id: telegram_user.id]
          render(t[:real_user][:existent] %
            {name: user.full_name, alias: user.alias, mention: mention_text})
        else
          user = Alias.create_real_user(@chat.id, telegram_user)

          render(t[:real_user][:created] %
            {name: user.full_name, alias: user.alias, mention: mention_text})
        end
      else
        render(t[:real_user][:no_telegram_user] % {mention: mention_text})
      end
    end

    render(t[:first_time]) if @first_time

    :final_state
  end

  def virtual_user_initial_state(msg)
    render(t[:virtual_user][:name?])

    :virtual_user_name_state
  end

  def virtual_user_name_state(msg)
    name = msg.text.match(/^[[:alpha:]][[:print:]]*/)

    if name.nil?
      raise BotError, t[:virtual_user][:no_name]
    end

    user = Alias.create_virtual_user(@chat.id, name.to_s)

    render(t[:virtual_user][:created] %
      {name: user.full_name, alias: user.alias})

    :final_state
  end

  def virtual_to_real_user_initial_state(msg)
    virtual_users = Alias.virtual_users(@chat.id).all

    if virtual_users.empty?
      raise BotCancelError, t[:virtual_to_real_user][:no_virtual_users]
    end

    render(t[:virtual_to_real_user][:virtual_user?],
      keyboard: keyboard(user_buttons(virtual_users).unshift(t[:cancel])))

    :virtual_to_real_user_virtual_user_state
  end

  def virtual_to_real_user_virtual_user_state(msg)
    @user = Alias.find_user(@chat.id, alias_helper(msg))

    render(t[:virtual_to_real_user][:mention?] % {name: @user.first_name})

    :virtual_to_real_user_mention_state
  end

  def virtual_to_real_user_mention_state(msg)
    mention = msg
      .entities
      .select{ |e| e.type =~ /mention/ }
      .first ||
      self_mention_helper(msg)

    raise BotError, t[:real_user][:no_mentions] unless mention

    mention_text = msg.text.slice(mention.offset, mention.length)

    if telegram_user = mention.user
      if user = Alias[chat_id: @chat.id, user_id: telegram_user.id]
        raise BotCancelError, t[:virtual_to_real_user][:existent] %
          {name_real:     user.full_name,
           alias_real:    user.alias,
           name_virtual:  @user.full_name,
           alias_virtual: @user.alias,
           mention:       mention_text}
      else
        @user.to_real_user(telegram_user)

        render(t[:virtual_to_real_user][:success] %
          {name: @user.full_name,
           alias: @user.alias,
           mention: mention_text})
      end
    else
      raise BotCancelError,
        t[:real_user][:no_telegram_user] % {mention: mention_text}
    end

    :final_state
  end

  def delete_user_initial_state(msg)
    user_list = Transaction.balance(@chat.id).map do |user|
      name = name_helper(user[:first_name], user[:last_name], user[:user_id])

      if (user[:balance] || 0).zero?
        t[:user][:deletable_item] % {name: name, alias: user[:alias]}
      else
        t[:user][:undeletable_item] %
          {name: name, alias: user[:alias], balance: currency(user[:balance])}
      end
    end

    raise BotCancelError, t[:user][:no_users] if user_list.empty?

    render(user_list.join("\n") + "\n" + t[:user][:delete_legend])

    :final_state
  end
end
