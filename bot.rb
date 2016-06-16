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

def process(bot, message)
  case message.text
  # TODO: Numeral separators.
  when /^\/p(?:ay|aid|ague|agué|ago)?\s+(.+)\s*:\s*(.+)\s*/i
    begin
      date    = Time.at(message.date).utc.to_date
      concept = Regexp.last_match[1]
      contributions = Regexp.last_match[2]
      transactions  = []

      loop do
        # This separates the first single contribution from the rest.
        con = contributions.match /^(\S+)(?:\s+(.+))?\s*/

        # Just in case...
        raise "Sadness hasn't got end: single contribution " \
              "from '#{contributions}' is nil." if con.nil?

        r = /^(\d{0,19}(?:[\.,]\d{1,4})?)
              ([[:alpha:]]+)
              ((?:-(?=[\.,]?\d))?\d{0,19}(?:[\.,]\d{1,4})?)$/x

        c = con[1].match(r)

        raise text['transaction']['match_error'] % {chunk: con[1]} if c.nil?

        a = Alias.find(chat_id: message.chat.id, alias: c[2])

        raise text['transaction']['alias_error'] % {alias: c[2]} if a.nil?

        t = Transaction.new
        t.user_id    = a.user_id
        t.chat_id    = message.chat.id
        t.message_id = message.message_id
        t.date       = date
        t.concept    = concept
        t.contribution   = BigDecimal.new(c[3].empty? ? 0 : c[3].sub(',','.'))
        t.expense_factor = BigDecimal.new(c[1].empty? ? 1 : c[1].sub(',','.'))

        transactions << t

        contributions = con[2]
        break if contributions.nil?
      end

      contribution_sum   = 0
      expense_factor_sum = 0

      transactions.each do |t|
        contribution_sum   += t.contribution
        expense_factor_sum += t.expense_factor
      end

      DB.transaction do
        transactions.each do |t|
          individual_expense =
            contribution_sum / expense_factor_sum * t.expense_factor

          t.amount = t.contribution - individual_expense
          t.save
        end
      end

      bot.api.send_message(chat_id: message.chat.id,
                           text: text['transaction']['success'] %
                             {code: message.message_id},
                           parse_mode: 'Markdown')
    rescue => e
      bot.api.send_message(chat_id: message.chat.id,
                           text: e.message,
                           parse_mode: 'Markdown')
    end
  when /^\/balance\s*/i
    Alias.where(chat_id: message.chat.id).order(:alias).each do |a|
      m = bot.api
        .get_chat_member(user_id: a.user_id, chat_id: message.chat.id)

      balance =
        Transaction
        .where(user_id: a.user_id, chat_id: message.chat.id).sum(:amount)

      bot.api.send_message(chat_id: message.chat.id,
                           text: "#{m['result']['user']['first_name']}: #{balance}")
    end
  when /^\/borrar\s+([[:digit:]]+)\s*/i
    code = Regexp.last_match[1]

    n =
      Transaction
      .where(chat_id: message.chat.id, message_id: code)
      .delete

    t =
      if n != 0
        text['transaction']['delete']['success']
      else
        text['transaction']['delete']['failure']
      end

    bot.api.send_message(chat_id: message.chat.id,
                         text: t % {code: code},
                         parse_mode: 'Markdown')
  when /^\/start\s*/i
    bot.api.send_message(chat_id: message.chat.id,
                         text: text['welcome'],
                         parse_mode: 'Markdown')
  when /^\/yo\s+([[:alpha:]]+)\s*/i
    _alias = Regexp.last_match[1]

    if _alias
      _alias.downcase!

      a = Alias.find_or_create(user_id: message.from.id,
                               chat_id: message.chat.id) do |r|
        r.alias = _alias
      end

      t =
        if a.alias == _alias
          text['alias']['good'] % {user:  message.from.first_name,
                                   alias: _alias}
        else
          if b = Alias.find(chat_id: message.chat.id, alias: _alias)
            text['alias']['taken'] % {user:  message.from.first_name,
                                      alias: _alias,
                                      other_user: b.user_id}
          else
            a.update(alias: _alias)
            text['alias']['good'] % {user:  message.from.first_name,
                                     alias: _alias}
          end
        end
    else
      t = text['alias']['bad'] % {user: message.from.first_name}
    end

    bot.api.send_message(chat_id: message.chat.id,
                         text: t,
                         parse_mode: 'Markdown')
  else
    bot.api.send_message(chat_id: message.chat.id,
                         text: text['unknown_command'],
                         parse_mode: 'Markdown')
  end
end

token = '184269339:AAHg3gCErtyTX9dkQAgSs8746Qs3kwTtDUk'

Telegram::Bot::Client.run(token) do |bot|
  bot.listen do |message|
    process(bot, message)
  end
end
