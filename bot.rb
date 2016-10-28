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

class RRPP < Sequel::Model
  unrestrict_primary_key
  one_to_many :recommendations
end

class Recommendation < Sequel::Model
  unrestrict_primary_key
  many_to_one :rrpp
end

class Machine
  @@machines = {}

  HIDE_KB = Telegram::Bot::Types::ReplyKeyboardHide
    .new(hide_keyboard: true)

  def self.dispatch(bot, msg)
    m = @@machines[msg.chat.id] ||= Machine.new(bot, msg)
    m.dispatch(msg)

    @@machines.delete(msg.chat.id) if m.closed?
    return m
  end

  def initialize(bot, msg)
    @bot   = bot
    @chat  = msg.chat
    @state = :initial_state
    @originator = msg.from
  end

  def closed?
    @state == :final_state
  end

  def render(text, keyboard: HIDE_KB, chat_id: nil)
    puts "SENT to #{@originator.first_name} @ #{@chat.title || @chat.id}",
      text, '----'

    @bot.api.send_message(
      chat_id: chat_id || @chat.id,
      text: text,
      parse_mode: 'Markdown',
      reply_markup: keyboard)
  end

  def dispatch(msg)
    puts "RECEIVED from #{msg.from.first_name} @ #{@chat.title || @chat.id}",
      msg.text, '----'

    if msg.text
      if msg.text.match(/^\/?cancelar/i)
        render(t[:canceled_command])
        @state = :final_state

      elsif @state != :initial_state && command_helper(msg)
        render(t[:ongoing_command] % {command: escape(command_helper(msg))})

      elsif @originator.id == msg.from.id
        @state =
          begin
            # State methods must return the next state.
            send(@state, msg)
          rescue BotError => e
            # keyboard: nil should maintain the present keyboard before
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
        render(t[:hello] % {name: escape(msg.new_chat_member.first_name)})
      end
    elsif msg.left_chat_member
      if msg.left_chat_member.username == BOT_NAME
        # Dineros was kicked from the chat.
        # x_x
        Alias.obliterate(@chat.id)
      else
        # A member was kicked from the chat instead.
        render(t[:bye] % {name: escape(msg.left_chat_member.first_name)})
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
    when /^\/rrpp/i        then rrpp_initial_state(msg)
    else
      # If an instance of Machine do not reach a final state it will not
      # be garbage collected. On the other hand in an active conversation
      # frequent messages will instantiate often...
      :final_state
      #@state
    end
  end
end

def one_on_one_initial_state(msg)
  return :final_state unless msg.chat.type == 'private'

  render(t[:start])

  if msg.text.match(/^\/start (?<rrpp_code>[[:digit:]]+)/i) &&
      rrpp = RRPP[ Regexp.last_match[:rrpp_code] ]

    if rrpp.user_id != msg.from.id && !Recommendation[msg.from.id]

      rrpp.add_recommendation(
        user_id:    msg.from.id,
        first_name: msg.from.first_name,
        last_name:  msg.from.last_name
      )

      converted_name = name(msg.from.first_name, msg.from.last_name)

      render(t[:recommendation] %
        {rrpp_name:      escape(rrpp.first_name),
         converted_name: converted_name,
         conversions:    rrpp.recommendations_dataset.count},
        chat_id: rrpp.user_id
      )
    end
  end

  :final_state
end

def help_initial_state(msg)
  render(t[:help])
  :final_state
end

def rrpp_initial_state(msg)
  RRPP.find_or_create(
    user_id:    msg.from.id,
    first_name: msg.from.first_name,
    last_name:  msg.from.last_name
  )

  render(t[:to_share])

  render(
    escape("https://telegram.me/#{BOT_NAME}?start=#{msg.from.id}")
  )

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
