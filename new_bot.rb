require 'pry'
require 'sequel'
require 'telegram/bot'
require 'telegram/bot/botan'
require 'bigdecimal'
require 'yaml'
require 'action_view'

BOT_NAME    = ENV['DINEROS_BOT_NAME']
BOT_TOKEN   = ENV['DINEROS_BOT_TOKEN']

bot = Telegram::Bot::Client.new(BOT_TOKEN)

bot.listen do |message|
  #bot.track(message.text, message.from.id)
  Machine.dispatch(bot, message)
end
begin
  Telegram::Bot::Client.run(BOT_TOKEN) do |bot|
    bot.enable_botan!(BOTAN_TOKEN)
    puts 'Dineros is running.', '----'

  end
rescue Faraday::ConnectionFailed => e
  puts e.message, '----'
  sleep 10
  retry
end


