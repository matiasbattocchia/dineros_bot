require 'pry'
require 'sequel'
require 'telegram/bot'
require 'telegram/bot/botan'
require 'bigdecimal'
require 'yaml'

BOT_NAME    = 'dev_dineros_bot'
BOT_TOKEN   = ENV['DINEROS_BOT_TOKEN']
BOTAN_TOKEN = ENV['DINEROS_BOTAN_TOKEN']

DB = Sequel.connect('postgres://localhost/dineros')

module Kernel
  @@text ||= YAML.load_file('i18n.yml')

  def t(locale = 'es')
    @@text[locale]
  end
end

require_relative 'helpers'
require_relative 'alias'
require_relative 'payment'
require_relative 'payment_states'
require_relative 'loan_states'
require_relative 'balance_states'
require_relative 'user_states'
require_relative 'delete_states'

class BotError < StandardError
end

class Machine
  @@machines = {}

  DIALOG_BUTTONS = ['/cancelar', '/confirmar']

  HIDE_KB = Telegram::Bot::Types::ReplyKeyboardHide
    .new(hide_keyboard: true)

  FORCE_KB = Telegram::Bot::Types::ForceReply
    .new(force_reply: true, selective: true)

  def self.dispatch(bot, msg)
    m = @@machines[msg.chat.id] ||= Machine.new(bot, msg.chat.id)
    m.dispatch(msg)

    @@machines.delete(msg.chat.id) if m.closed?
    return m
  end

  def initialize(bot, chat_id)
    @bot     = bot
    @chat_id = chat_id
    @state   = :initial_state
  end

  def closed?
    @state == :final_state
  end

  def render(text, keyboard: nil, reply_to: nil)
    puts 'SENT:', text, '----'

    @bot.api.send_message(
      chat_id: @chat_id,
      reply_to_message_id: reply_to&.message_id,
      text: text,
      parse_mode: 'Markdown',
      reply_markup: keyboard)
  end

  def dispatch(msg)
    puts 'RECEIVED:', msg.text, '----'

    if msg.text
      if msg.text.match /^\/cancelar/
        render(t[:canceled], keyboard: HIDE_KB)
        @state = :final_state
      elsif @state != :initial_state &&
        msg.text.match(/^\/(p|balance|usuarios|eliminar)/)
        render(t[:ongoing_command] % {command: Regexp.last_match[1]})
      else
        begin
          # State methods must return the next state.
          @state = send(@state, msg)
        rescue BotError => e
          render(e.message)
          @state = :final_state if @state == :initial_state
        end
      end
    elsif msg.new_chat_member
      if msg.new_chat_member.username == BOT_NAME
        # Dineros has been invited to a chat.
        # ^_^
        render(t[:welcome])
      else
        # The chat has a new member.
        Alias.create_real_user(@chat_id, msg.new_chat_member)
        render(t[:hello] % {name: msg.new_chat_member.first_name})
      end
    elsif msg.left_chat_member
      if msg.left_chat_member.username == BOT_NAME
        # Dineros was kicked from the chat.
        # x_x
      else
        # A member was kicked from the chat instead.
        user = Alias[chat_id: chat_id, user_id: msg.left_chat_member.id]
        user.to_virtual_user
        render(t[:bye] % {name: msg.left_chat_member.first_name})
      end
    else
      #binding.pry
    end
  end

  def initial_state(msg)
    case msg.text
    when /^\/p(ago)?/  then payment_initial_state(msg)
    when /^\/préstamo/ then loan_initial_state(msg)
    when /^\/balance/  then balance_initial_state(msg)
    when /^\/usuarios/ then users_initial_state(msg)
    when /^\/eliminar/ then delete_initial_state(msg)
    else
      render(t[:unknown_command])
      :final_state
    end
  end

end

Telegram::Bot::Client.run(BOT_TOKEN) do |bot|
  bot.enable_botan!(BOTAN_TOKEN)
  puts 'Dineros is running.'

  bot.listen do |message|
    #bot.track(message.text, message.from.id)
    Machine.dispatch(bot, message)
  end
end
