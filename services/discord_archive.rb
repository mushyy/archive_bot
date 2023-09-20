module AutoArchive
  module Discord
    Bot.channel_create do |event|
      # Check if the channel name starts with "ticket"
      if event.channel.name.downcase.start_with?(ENV["TICKET_CHANNEL_PREFIX"].downcase)
        # Start listening for messages in the newly created channel
        start_listening_in_channel(event.channel)
      end
    end
    # Function to start listening for messages in a specific channel
    def self.start_listening_in_channel(channel)
      # Get the ticket number / name from the channel name
      ticket = channel.name.downcase
      Bot.message(in: channel) do |event|
        # Check if the message is an attachment
        unless event.message.attachments.empty?
          # Loop through each attachment
          event.message.attachments.each do |attachment|
            # Get the file extension, local directory and local file path
            file_extension = File.extname(attachment.filename)
            local_directory = "tmp/#{ticket}"
            local_file_path = File.join(local_directory, attachment.filename)
            # Create the local directory if it doesn't exist
            FileUtils.mkdir_p(local_directory) unless File.directory?(local_directory)    
            # Get the file URL from Discord
            uri = URI.parse(attachment.url)
            # Get response of the file
            response = Net::HTTP.get_response(uri)
            # Check if the response is successful
            if response.is_a?(Net::HTTPSuccess)
              # Write the file to the local directory
              File.open(local_file_path, 'wb') do |local_file|
                local_file.write(response.body)
              end
              # Upload the file to the archive channel
              uploaded_message = Bot.channel(ENV["EVIDENCE_CHANNEL_ID"]).send_file(File.open(local_file_path, 'rb'))
              # Respond to ticket channel with link to archived file
              event.channel.send_message("[Archived](#{uploaded_message.attachments.first.url})")
              # Delete the local file
              File.delete(local_file_path)
            else
              $logger.error "Failed to download #{attachment.filename}: #{response.code} #{response.message}"
            end
          end
        end
      end
    end
  end
end