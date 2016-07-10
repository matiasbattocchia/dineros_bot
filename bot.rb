require 'pry'
require 'sequel'
require 'telegram/bot'
require 'bigdecimal'
require 'yaml'

def text(locale = 'es')
  @text ||= YAML.load_file('i18n.yml')
  @text[locale]
end

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

# TODO: A Sinatra approach
#
# command 'start' do
#   message...
#   bot...
# end

# TODO: Command redirect
# For example, if a command has bad formatting,
# append the results of a help command to the error
# message.

# TODO: How to round money the right way?

def process(bot, message)
  begin
    case message.text
    # TODO: Numeral separators.
    when /^\/p(?:ay|aid|ague|agué|ago)?\s+(.+)\s*:\s*(.+)\s*/i
      date    = Time.at(message.date).utc.to_date
      concept = Regexp.last_match[1]
      contributions = Regexp.last_match[2]
      transactions  = []

      loop do
        # This separates the first single contribution from the rest.
        con = contributions.match /^(\S+)(?:\s+(.+))?\s*/

        # Just in case...
        #raise "Sadness hasn't got end: single contribution " \
        #      "from '#{contributions}' is nil." if con.nil?

        r = /^(\d{0,15}(?:[\.,]\d{1,4})?)
              ([[:alpha:]]+)
              ((?:-(?=[\.,]?\d))?\d{0,15}(?:[\.,]\d{1,4})?)$/x

        c = con[1].match(r)

        raise BotError,
          text['transaction']['match_error'] % {chunk: con[1]} if c.nil?

        a = Alias.find(chat_id: message.chat.id, alias: c[2])

        raise BotError,
          text['transaction']['alias_error'] % {alias: c[2]} if a.nil?

        t = Transaction.new
        t.alias_id   = a.id
        t.message_id = message.message_id
        t.date       = date
        t.concept    = concept
        t.contribution = BigDecimal.new(c[3].empty? ? 0 : c[3].sub(',','.'))
        t.factor       = BigDecimal.new(c[1].empty? ? 1 : c[1].sub(',','.'))

        transactions << t

        contributions = con[2]
        break if contributions.nil?
      end

      contribution_sum   = 0
      factor_sum = 0

      transactions.each do |t|
        contribution_sum   += t.contribution
        factor_sum += t.factor
      end

      begin
        DB.transaction do
          transactions.each do |t|
            co_contribution =
              contribution_sum / factor_sum * t.factor

            t.amount = t.contribution - co_contribution
            t.save
          end
        end
      rescue Sequel::UniqueConstraintViolation
        raise BotError,
          text['transaction']['repeated_alias_error']
      end

      bot.api.send_message(chat_id: message.chat.id,
                           text: text['transaction']['success'] %
                             {code: message.message_id},
                           parse_mode: 'Markdown')

    when /^\/balance\s*/i
      b = Transaction
        .right_join(Alias.where(chat_id: message.chat.id), :id=>:alias_id)
        .select_group(:alias, :name)
        .select_append{sum(:amount).as(:balance)}.order(:name)
        .map(&:values).map do |a|
          (text['balance']['item'] %
            {alias: a[:alias], user: a[:name], balance: a[:balance] || 0})
            .sub('.',',')
      end

      t = if b.empty?
        text['balance']['nothing']
      else
        b.join("\n")
      end

      bot.api.send_message(
        chat_id: message.chat.id,
        text: t,
        parse_mode: 'Markdown')

    when /^\/borrar\s+([[:digit:]]+)\s*/i
      code = Regexp.last_match[1]

      n = Transaction
            .where(chat_id: message.chat.id, message_id: code)
            .delete

      t = if n != 0
        text['transaction']['delete']['success']
      else
        text['transaction']['delete']['failure']
      end

      bot.api.send_message(chat_id: message.chat.id,
                           text: t % {code: code},
                           parse_mode: 'Markdown')

    when /^\/ayuda\s*/i
      bot.api.send_message(chat_id: message.chat.id,
                           text: text['help'],
                           parse_mode: 'Markdown')

    when /^\/ejemplos\s*/i
      bot.api.send_message(chat_id: message.chat.id,
                           text: text['examples'],
                           parse_mode: 'Markdown')

    when /^\/apodo\s+([[:alpha:]]{1,8})(?:\s+(.+))?\s*/i
      # When name is blank, an alias for the message originator
      # will be created; when it is present a 'dummy user'
      # will be created, which later can be claimed
      # by a real user.
      _alias = Regexp.last_match[1].downcase
      name   = Regexp.last_match[2]

      a = Alias.find(chat_id: message.chat.id, alias: _alias)

      if a
        raise BotError,
          text['alias']['taken'] %
            {alias: a.alias,
             other_user: a.name} if a.user_id || name

        a.user_id = message.from.id
        a.name    = message.from.first_name
      else
        a = Alias.new
        a.user_id = name ? nil : message.from.id
        a.chat_id = message.chat.id
        a.alias   = _alias
        a.name    = name ? "#{name} (dummy)" : message.from.first_name
      end

      begin
        a.save
      rescue Sequel::UniqueConstraintViolation
        a = Alias.find(user_id: message.from.id,
                       chat_id: message.chat.id)

        raise BotError,
          text['alias']['existent'] % {alias: a.alias}
      end

      bot.api.send_message(chat_id: message.chat.id,
                           text: text['alias']['good'] %
                             {user:  a.name, alias: a.alias},
                           parse_mode: 'Markdown')
    end
  rescue => e
    mode = e.instance_of?(BotError) ? 'Markdown' : nil

    bot.api.send_message(chat_id: message.chat.id,
                         text: e.message,
                         parse_mode: mode)
  end
end

token = ENV['DINEROS_BOT_TOKEN']

Telegram::Bot::Client.run(token) do |bot|
  bot.listen do |message|
    process(bot, message)
  end
end
