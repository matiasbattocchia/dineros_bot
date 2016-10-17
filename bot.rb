require 'pry'
require 'sequel'
require 'telegram/bot'
require 'telegram/bot/botan'
require 'bigdecimal'
require 'yaml'

BOT_NAME    = ENV['DINEROS_BOT_NAME']
BOT_TOKEN   = ENV['DINEROS_BOT_TOKEN']
BOTAN_TOKEN = ENV['DINEROS_BOTAN_TOKEN']

DB = Sequel.connect('postgres://localhost/dineros')

# Aux
require_relative 'helpers'

# Models
require_relative 'alias'
require_relative 'payment'

# States
require_relative 'calculation_states'
require_relative 'payment_states'
require_relative 'loan_states'
require_relative 'balance_states'
require_relative 'user_states'
require_relative 'delete_states'

class BotError < StandardError
end

class Machine
  @@machines = {}

  HIDE_KB = Telegram::Bot::Types::ReplyKeyboardHide
    .new(hide_keyboard: true)

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

  def render(text, keyboard: HIDE_KB, reply_to: nil)
    puts 'SENT:', text, '----'

    @bot.api.send_message(
      chat_id: @chat_id,
      #reply_to_message_id: reply_to&.message_id,
      text: text,
      parse_mode: 'Markdown',
      reply_markup: keyboard)
  end

  def dispatch(msg)
    puts 'RECEIVED:', msg.text, '----'

    if msg.text
      if msg.text.match(/^\/?cancelar/i)
        render(t[:canceled], keyboard: HIDE_KB)
        @state = :final_state

      elsif @state != :initial_state && msg.text
        .match(/^\/[[:alnum:]]+/)

        render(t[:ongoing_command] % {command: Regexp.last_match[0]})
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
        #Alias.create_real_user(@chat_id, msg.new_chat_member)
        render(t[:hello] % {name: msg.new_chat_member.first_name})
      end
    elsif msg.left_chat_member
      if msg.left_chat_member.username == BOT_NAME
        # Dineros was kicked from the chat.
        # x_x
        Alias.obliterate(@chat_id)
      else
        # A member was kicked from the chat instead.
        if user = Alias[chat_id: @chat_id, user_id: msg.left_chat_member.id]
          user.to_virtual_user
          render(t[:bye] %
            {name: name_helper(user.first_name, user.last_name, true),
             alias: user.alias})
        end
      end
    else
      puts 'Weird event.', msg, '----'
    end
  end

  def initial_state(msg)
    case msg.text
    when /^\/(p\s|pago)/  then payment_initial_state(msg)
    when /^\/pr[eé]stamo/ then loan_initial_state(msg)
    when /^\/balance/     then balance_initial_state(msg)
    when /^\/c[aá]lculo/  then calculation_initial_state(msg)
    when /^\/usuarios/    then users_initial_state(msg)
    when /^\/eliminar/    then delete_initial_state(msg)
    when /^\/start/       then one_on_one_initial_state(msg)
    when /^\/ayuda/       then help_initial_state(msg)
    else
      # If an instance of Machine do not reach a final state it will not
      # be garbage collected. On the other hand in an active conversation
      # frequent messages will instantiate often...
      #:final_state
      @state
    end
  end
end

def one_on_one_initial_state(msg)
  render(t[:start])
  :final_state
end

def help_initial_state(msg)
  render(t[:help])
  :final_state
end

begin
  Telegram::Bot::Client.run(BOT_TOKEN) do |bot|
    bot.enable_botan!(BOTAN_TOKEN)
    puts 'Dineros is running.', '----'

    bot.listen do |message|
      #bot.track(message.text, message.from.id)
      Machine.dispatch(bot, message)
    end
  end
rescue Faraday::ConnectionFailed => e
  puts e.message, '----'
  sleep 10
  retry
end
