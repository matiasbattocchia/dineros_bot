class Machine
  def date_helper(msg)
    Time.at(msg.date).utc.to_date
  end

  def alias_helper(msg)
    msg.text.match(/^\(([[:alpha:]]+)\)/)

    if Regexp.last_match.nil?
      raise BotError, t[:helper][:alias_error]
    end

    Regexp.last_match[1]
  end

  def user_buttons(chat_id)
    Alias.active_users(chat_id).map do |a|
      ['(' + a.alias + ')', a.first_name, a.last_name].compact.join(' ')
    end
  end
end
