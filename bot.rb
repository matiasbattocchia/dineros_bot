require 'pry'
require 'sequel'
require 'telegram/bot'
require 'telegram/bot/botan'
require 'bigdecimal'
require 'yaml'
require 'action_view'

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

class BotCancelError < StandardError
end

class Machine
  @@machines = {}

  HIDE_KB = Telegram::Bot::Types::ReplyKeyboardHide
    .new(hide_keyboard: true)

  def self.dispatch(bot, msg)
    m = @@machines[msg.chat.id] ||= Machine.new(bot, msg.chat)
    m.dispatch(msg)

    @@machines.delete(msg.chat.id) if m.closed?
    return m
  end

  def initialize(bot, chat)
    @bot     = bot
    @chat_id = chat.id
    @chat    = chat
    @state   = :initial_state
  end

  def closed?
    @state == :final_state
  end

  def render(text, keyboard: HIDE_KB, reply_to: nil)
    puts "SENT to #{@chat.title || @chat.id}", text, '----'

    @bot.api.send_message(
      chat_id: @chat.id,
      #reply_to_message_id: reply_to&.message_id,
      text: text,
      parse_mode: 'Markdown',
      reply_markup: keyboard)
  end

  def dispatch(msg)
    puts "RECEIVED from #{msg.from.first_name} @ #{@chat.title || @chat.id}",
      msg.text, '----'

    if msg.text
      if msg.text.match(/^\/?cancelar/i)
        render(t[:canceled])
        @state = :final_state

      elsif @state != :initial_state && command_helper(msg)
        render(t[:ongoing_command] % {command: command_helper(msg)})

      else
        @state =
          begin
            # State methods must return the next state.
            send(@state, msg)
          rescue BotError => e
            # keyboard: nil should maintain the keyboard present before
            # the exception.
            render(e.message, keyboard: nil)
            @state == :initial_state ? :final_state : @state
          rescue BotCancelError => e
            render(e.message)
            :final_state
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
        Alias.obliterate(@chat.id)
      else
        # A member was kicked from the chat instead.
        if user = Alias[chat_id: @chat.id, user_id: msg.left_chat_member.id]
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
    when /^\/(p\s|pago)/i  then payment_initial_state( group_chat_only(msg) )
    when /^\/pr[eé]stamo/i then loan_initial_state( group_chat_only(msg) )
    when /^\/balance/i     then balance_initial_state( group_chat_only(msg) )
    when /^\/c[aá]lculo/i  then calculation_initial_state(msg)
    when /^\/usuarios/i    then users_initial_state( group_chat_only(msg) )
    when /^\/eliminar/i    then delete_initial_state( group_chat_only(msg) )
    when /^\/start/i       then one_on_one_initial_state(msg)
    when /^\/ayuda/i       then help_initial_state(msg)
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
