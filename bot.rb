require 'pry'
require 'sequel'
require 'telegram/bot'
require 'bigdecimal'
require 'yaml'

require_relative 'helpers'
require_relative 'alias'
require_relative 'transaction'
require_relative 'payment_states'
require_relative 'loan_states'
require_relative 'balance_states'
require_relative 'delete_states'

BOT_NAME = 'dineros_bot'

DB = Sequel.connect('postgres://localhost/dineros')

class BotError < StandardError
end

class Alias < Sequel::Model
  unrestrict_primary_key
end

class Transaction < Sequel::Model
  unrestrict_primary_key
end

class Account < Sequel::Model
  unrestrict_primary_key
end

class Machine
  @@machines = {}
  @@text ||= YAML.load_file('i18n.yml')

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

  def t(locale = 'es')
    @@text[locale]
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
    puts text

    @bot.api.send_message(
      chat_id: @chat_id,
      reply_to_message_id: reply_to&.message_id,
      text: text,
      parse_mode: 'Markdown',
      reply_markup: keyboard)
  end

  def dispatch(msg)
    if msg.text
      if msg.text.match /^\/cancelar/
        render(t[:canceled], keyboard: HIDE_KB)
        @state = :final_state
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
        render(t[:hello] % {name: msg.new_chat_member.first_name})
      end
    elsif msg.left_chat_member
      if msg.left_chat_member.username == BOT_NAME
        # Dineros was kicked from the chat.
        # x_x
      else
        # A member was kicked from the chat instead.
        render(t[:bye] % {name: msg.left_chat_member.first_name})
      end
    else
      binding.pry
    end
  end

  def initial_state(msg)
    case msg.text
    when /^\/inicio/   then start
    when /^\/p(ago)?/  then payment_initial_state(msg)
    when /^\/préstamo/ then loan_initial_state(msg)
    when /^\/balance/  then balance_initial_state(msg)
    when /^\/eliminar/ then delete_initial_state(msg)
    else
      render(t[:unknown_command])
      :final_state
    end

  def start(msg)
    users = msg
      .entities
      .select{ |e| e.type =~ /mention/ }
      .map(&:user)

    if users.any?
      @text = []

      users.each do |user|
        @text << create_or_update_alias(user)
      end

    @state = :final_state
  end
end

token = ENV['DINEROS_BOT_TOKEN']

Telegram::Bot::Client.run(token) do |bot|
  bot.listen do |message|
    Machine.dispatch(bot, message)
  end
end
