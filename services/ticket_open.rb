module AutoArchive
  module TicketOpen
    # Event handler to detect when a channel is created
    Bot.channel_create do |event|
      # Check if the channel name starts with "ticket"
      if event.channel.name.downcase.start_with?(ENV["TICKET_CHANNEL_PREFIX"].downcase)
        # Start listening for messages in the newly created channel
        if ENV["NOTIFY_ARCHIVE_START"]&.downcase == "true"
          event.channel.send_message("Please upload all relevant files to Discord, YouTube, Streamable, MedalTV or Gyazo.")
        end
      end
    end
  end
end