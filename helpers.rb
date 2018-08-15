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

  def command_helper(msg)
    msg.text.match(/^\/[[[:alnum:]]_]*/)&.to_s
  end

  MONO = '`'
  BOLD = '*'
  ITAL = '_'
  NONE = ''

  def name(first_name, last_name, _alias = nil, style = BOLD)

    name = []
    name << "#{style}(" + _alias + ")#{style}" if _alias
    name << escape(first_name)
    name << escape(last_name) if last_name

    name.join(' ')
  end

  def message_helper(text)
    Telegram::Bot::Types::Message.new(text: text)
  end

  def pseudouser_helper(name)
    Alias.new(first_name: name)
  end

  def keyboard(buttons)
    Telegram::Bot::Types::ReplyKeyboardMarkup.new(
      keyboard: buttons, resize_keyboard: true)
  end

  def inline_keyboard(buttons)
    Telegram::Bot::Types::InlineKeyboardMarkup.new(
      inline_keyboard: buttons)
  end

  def inline_button(options)
    Telegram::Bot::Types::InlineKeyboardButton.new(options)
  end

  def user_buttons(users)
    users.map(&:name)
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

  def active_users(chat_id)
    Alias.active_users(chat_id).all
  end

  # Escapes markdown-related characters for Telegram Bot API
  def escape(text)
    # If we see a backtick, underscore, or asterisk escape it with backlash
    text.gsub(/`|_|\*/) { |char| "\\" + char }
  end
end
