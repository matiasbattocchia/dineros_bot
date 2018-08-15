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
require_relative 'models/alias'
require_relative 'models/payment'

# States
require_relative 'states/calculation'
require_relative 'states/payment'
require_relative 'states/loan'
require_relative 'states/balance'
require_relative 'states/user'
require_relative 'states/delete'

class BotError < StandardError
end

class BotCancelError < StandardError
end

class Telegram::Bot::Types::CallbackQuery
  def chat
    message.chat
  end

  def text
    data
  end
end


class Machine
  @@machines = {}

  RM_KB = Telegram::Bot::Types::ReplyKeyboardRemove
    .new(remove_keyboard: true)

  LOG = true

  def self.log_input(msg)
    return unless LOG

    puts "RECEIVED from #{msg.from.first_name} @ " \
         "#{msg.chat.title || msg.chat.id} at " \
         "#{Time.now.strftime '%b %d %H:%M:%S'}",
         msg.text,
         '----'
  end

  def self.log_output(msg)
    return unless LOG

    puts "SENT to #{@from.first_name} @ " \
         "#{@chat.title || @chat.id} at " \
         "#{Time.now.strftime '%b %d %H:%M:%S'}",
         text,
         '----'
  end

  def self.dispatch(bot, msg)
    log_input(msg)

    m = @@machines[msg.from.id] ||= Machine.new(bot, msg)
    m.dispatch(msg)

    # The machine can change in the middle (redispatched), that is why we
    # retrieve it from '@@machines' again instead of calling 'm'.
    @@machines.delete(msg.from.id) if @@machines[msg.from.id].closed?
  end

  def self.redispatch(bot, msg)
    m = @@machines[msg.from.id] = Machine.new(bot, msg)
    m.dispatch(msg)
  end

  def initialize(bot, msg)
    @bot   = bot
    @from  = msg.from
    @chat  = msg.chat
    @state = :initial_state
  end

  def closed?
    @state == :final_state || @state == :initial_state
  end

  def private?
    # type: private, group, supergroup, channel
    @chat.type == 'private'
  end

  def render(text, keyboard: RM_KB, inline_keyboard: nil, chat_id: nil,
             private: false, edit: nil)
    Machine.log_output(msg)

    if edit
      @bot.api.edit_message_text(
        chat_id: edit['result']['chat']['id'],
        message_id: edit['result']['message_id'],
        text: text,
        parse_mode: 'Markdown',
        reply_markup: inline_keyboard
      )
    else
      @bot.api.send_message(
        chat_id: chat_id || private ? @from.id : @chat.id,
        text: text,
        parse_mode: 'Markdown',
        reply_markup: keyboard
      )
    end
  end

  def dispatch(msg)
    case msg
    when Telegram::Bot::Types::Message
      dispatch_message(msg)
    when Telegram::Bot::Types::CallbackQuery
      dispatch_callback_query(msg)
    else
      puts "Message is a #{msg.class}, not managed by #dispatch."
    end
  end

  def dispatch_message(msg)
    if msg.text
      @state =
        begin
          # State methods must return the next state.
          #send(@state, msg)
          route(msg)
        rescue BotError => e
          # keyboard: nil should maintain the present keyboard before
          # the exception.
          render(e.message, keyboard: nil, private: true)
          @state
        rescue BotCancelError => e
          render(e.message, private: @state != :initial_state)
          :final_state
        end
    elsif msg.new_chat_member
      if msg.new_chat_member.username == BOT_NAME
        # The bot has been invited to a chat.  ^_^
        render(t[:start])
      else
        # The chat has a new member.
        render(
          t[:hello] % {name: escape(msg.new_chat_member.first_name)},
          keyboard: nil
        )
      end
    elsif msg.left_chat_member
      if msg.left_chat_member.username == BOT_NAME
        # The bot was kicked from the chat.  x_x
        Alias.obliterate(@chat.id)
      else
        # A member was kicked from the chat instead.
        render(
          t[:bye] % {name: escape(msg.left_chat_member.first_name)},
          keyboard: nil
        )
      end
    end
  end

  dispatch_callback_query(msg)
    case msg.data
    when /eliminar/i then delete_initial_state(msg)
    when /explicar/i then explain_initial_state(msg)
    else
      render(t[:unknown_command])
      :final_state
    end
  end

  def route(msg)
    if msg.text.match /^\// # It is a command (possibly).
      if @state == :initial_state
        case msg.text
        when /(p\s|pago)/i  then payment_initial_state(msg)
        when /pr[eé]stamo/i then loan_initial_state(msg)
        when /balance/i     then balance_initial_state(msg)
        #when /c[aá]lculo/i  then calculation_initial_state(msg)
        #when /nombres/i    then users_initial_state(msg)
        #when /eliminar/i    then delete_initial_state(msg)
        #when /explicar/i    then explain_initial_state(msg)
        when /start/i       then one_on_one_initial_state(msg)
        when /ayuda/i       then help_initial_state(msg)
        when /rrpp/i        then rrpp_initial_state(msg)
        else
          render(t[:unknown_command])
          :final_state
        end
      else # There is an ongoing command.
        Machine.redispatch(@bot, msg)
        :limbo_state
      end
    elsif @state != :initial_state && msg.chat.type == 'private'
      if msg.text.match /#{t[:cancel]}/i
        render(t[:canceled_command], private: true)
        :final_state
      else
        send(@state, msg)
      end
    else
      @state
    end
  end
end

def one_on_one_initial_state(msg)
  return :final_state unless private?

  render(t[:start])
  render(t[:start_private])

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
