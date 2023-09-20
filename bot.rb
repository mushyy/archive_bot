require 'discordrb'
require 'dotenv'
require 'logger'
require 'aws-sdk-s3'

Dotenv.load

# Define the logger instance
$logger = Logger.new($stdout)

# Initialize Discord bot
Bot = Discordrb::Bot.new(token: ENV["DISCORD_BOT_TOKEN"], intents: :all)

# Configure bot settings and event handlers
Bot.ready do
  $logger.info("Bot is ready!")
end

# Load Discord commands
Dir.glob(File.join(File.dirname(__FILE__), "commands", "*.rb")).each do |file|
  require file
end

# Load Discord services / websites to download from
Dir.glob(File.join(File.dirname(__FILE__), "services", "*.rb")).each do |file|
  require file
end

# Start the bot
Bot.run