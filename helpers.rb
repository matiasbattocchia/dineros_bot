module Kernel
  @@text ||= YAML.load_file('i18n.yml')

  def t(locale = 'es')
    @@text[locale]
  end

  def currency(amount)
    #ActionView::Helpers::NumberHelper
    ("%.2f" % amount).sub('.',',').sub(',00','')
  end

  def number(amount)
    ("%g" % amount).sub('.',',')
  end

  def date_helper(msg)
    Time.at(msg.date).utc.to_date
  end

  def alias_helper(msg)
    msg.text.match(/[[:alpha:]]/)

    if Regexp.last_match.nil?
      raise BotError, t[:alias_error]
    end

    Regexp.last_match[0].downcase
  end

  def command_helper(msg)
    msg.text.match(/^\/[[[:alnum:]]_]*/)
  end

  def name_helper(first_name, last_name, virtual_user)
    name = first_name
    name += ' ' + last_name if last_name
    name += ' (' + t[:virtual] + ')' if virtual_user
    name
  end

  def message_helper(text)
    Telegram::Bot::Types::Message.new(text: text)
  end

  def self_mention_helper(msg)
    # TODO: Not entirely convinced with the next regular expression.
    return unless offset = msg.text =~ /@$|@\s/

    Telegram::Bot::Types::MessageEntity.new(
      length: 1, offset: offset, user: msg.from)
  end

  def pseudouser_helper(name)
    Alias.new(first_name: name)
  end

  def keyboard(buttons)
    Telegram::Bot::Types::ReplyKeyboardMarkup.new(
      keyboard: buttons, resize_keyboard: true)
  end

  def user_buttons(users)
    users.map do |a|
      '(' + a.alias + ') ' + a.full_name
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

  def group_chat_only(msg)
    if msg.chat.type != 'group'
      raise BotCancelError,
        t[:group_chat_only] % {command: command_helper(msg)}
    end

    msg
  end

  def active_users(chat_id)
    active_users = Alias.active_users(chat_id).all

    case active_users.size
    when 0
      raise BotCancelError, t[:user][:no_active_users]
    when 1
      raise BotCancelError, t[:user][:single_active_user]
    end

    active_users
  end

  # Escapes markdown-related characters for Telegram Bot API
  def escape(text)
    # If we see a backtick, underscore, or asterisk escape it with backlash 
    text.gsub(/`|_|\*/) { |char| "\\#{char}" }
  end
end
