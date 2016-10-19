class Machine
  def users_initial_state(msg)
    options_kb = keyboard(t[:user][:menu])

    render(t[:user][:option?], keyboard: options_kb)

    :users_options_state
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
        if user = Alias[chat_id: @chat_id, user_id: telegram_user.id]
          render(t[:real_user][:existent] %
                 {existent: user.first_name, mention: mention_text})
        else
          user = Alias.create_real_user(@chat_id, telegram_user)

          render(t[:real_user][:created] %
                 {name: user.full_name,
                  alias: user.alias,
                  mention: mention_text})
        end
      else
        render(t[:real_user][:no_telegram_user] % {mention: mention_text})
      end
    end

    :final_state
  end

  def virtual_user_initial_state(msg)
    render(t[:virtual_user][:name?])

    :virtual_user_name_state
  end

  def virtual_user_name_state(msg)
    msg.text.match /^([[:alpha:]][[:print:]]*)/

    if Regexp.last_match.nil?
      raise BotError, t[:virtual_user][:no_name]
    end

    name = Regexp.last_match[1]

    user = Alias.create_virtual_user(@chat_id, name)

    render(t[:virtual_user][:created] %
           {name: user.full_name, alias: user.alias})

    :final_state
  end

  def virtual_to_real_user_initial_state(msg)
    virtual_users_kb = keyboard(
      user_buttons(Alias.virtual_users(@chat_id))
    )

    render(t[:virtual_to_real_user][:virtual_user?],
           keyboard: virtual_users_kb)

    :virtual_to_real_user_virtual_user_state
  end

  def virtual_to_real_user_virtual_user_state(msg)
    @user = Alias.find_user(@chat_id, alias_helper(msg))

    render(t[:virtual_to_real_user][:mention?] % {name: @user.full_name})

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
      if user = Alias[chat_id: @chat_id, user_id: telegram_user.id]
        raise BotError, t[:real_user][:existent] %
          {existent: user.first_name, mention: mention_text}
      else
        @user.to_real_user(telegram_user)

        render(t[:virtual_to_real_user][:success] %
               {name: @user.full_name,
                alias: @user.alias,
                mention: mention_text})
      end
    else
      raise BotError,
        t[:real_user][:no_telegram_user] % {mention: mention_text}
    end

    :final_state
  end

  def delete_user_initial_state(msg)
    user_list = Transaction.balance(@chat_id).map do |user|
      name = name_helper(user[:first_name], user[:last_name], user[:user_id])

      if (user[:balance] || 0).zero?
        t[:user][:deletable_item] % {name: name, alias: user[:alias]}
      else
        t[:user][:undeletable_item] %
          {name: name, alias: user[:alias], balance: user[:balance]}
      end
    end

    raise BotError, t[:user][:no_users] if user_list.empty?

    render(user_list.join("\n") + "\n" + t[:user][:delete_legend])

    :final_state
  end
end
