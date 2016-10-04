class Machine
  def create_or_update_alias(user)
    best_aliases = [
      user.first_name[0],
      user.last_name&.slice(0),
      user.username&.slice(0)
    ].compact.map(&:downcase)

    _alias = find_alias(best_aliases)

    full_name = [user.first_name, user.last_name].compact.join(' ')

    u = Alias.find(chat_id: @chat_id, user_id: user.id)

    if u
      result = u.update(
        alias: a,
        first_name: user.first_name,
        last_name: user.last_name,
        username: user.username)

      # result.nil? means that the record was not updated because
      # it has not changed, but everything is fine.
      if result || result.nil?
        render(t[:alias][:updated] % {name: full_name, alias: _alias})
      end
    else
      result = Alias.create(
        chat_id: @chat_id,
        user_id: user.id,
        alias: a,
        first_name: user.first_name,
        last_name: user.last_name,
        username: user.username)

      if result
        render(t[:alias][:created] % {name: full_name, alias: _alias})
      end
    end

    return result
  end

  def create_virtual_alias(name)
    if name.length > 16
      raise BotError, t[:alias][:name_too_long_error]
    end

    _alias = find_alias([name[0].downcase])

    result = Alias.create(
      chat_id: @chat_id,
      alias: _alias,
      first_name: name + ' ' + '(virtual)')

    if result
      render(t[:alias][:virtual_created] % {name: name, alias: _alias})
    end

    return result
  end
end
