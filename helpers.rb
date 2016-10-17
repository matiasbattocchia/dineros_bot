module Kernel
  @@text ||= YAML.load_file('i18n.yml')

  def t(locale = 'es')
    @@text[locale]
  end

  def money_helper(amount)
    ("%g" % ("%.2f" % amount)).sub('.',',')
  end

  def money_with_cents_helper(amount)
    ("%.2f" % amount).sub('.',',')
  end

  def date_helper(msg)
    Time.at(msg.date).utc.to_date
  end

  def alias_helper(msg)
    msg.text.match(/^[[:alpha:]]/)

    if Regexp.last_match.nil?
      raise BotError, t[:helper][:alias_error]
    end

    Regexp.last_match[0].downcase
  end

  def name_helper(first_name, last_name, user_id)
    name = first_name
    name += ' ' + last_name if last_name
    name += ' (' + t[:helper][:virtual] + ')' unless user_id
    name
  end

  def message_helper(text)
    Telegram::Bot::Types::Message.new(text: text)
  end

  def self_mention_helper(msg)
    return unless offset = msg.text =~ /@/

    Telegram::Bot::Types::MessageEntity.new(
      length: 1, offset: offset, user: msg.from)
  end

  def pseudouser_helper(name)
    Alias.new(alias: name.sub(' ','_'), first_name: name.sub('_',' '))
  end

  def keyboard(buttons)
    Telegram::Bot::Types::ReplyKeyboardMarkup.new(
      keyboard: buttons, resize_keyboard: true)
  end

  def user_buttons(users)
    users.map do |a|
      a.alias + ') ' + a.full_name
    end
  end

  def create_buttons
    [t[:cancel], t[:save]]
  end

  def delete_buttons
    [t[:cancel], t[:delete]]
  end

  def calculate_buttons
    [t[:cancel], t[:calculate]]
  end
end
