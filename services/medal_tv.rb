require_relative 's3'
module AutoArchive
  module MedalTv
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
        # Get message from event
        message = event.message
        # Check if the message contains any Medal TV URL
        medal_tv_url_matches = message.content.scan(%r{https://medal\.tv[^'"\s]+})
        # Loop through each Medal TV URL
        medal_tv_url_matches.each do |medal_tv_url|
          # Generate a random video ID
          video_id = SecureRandom.alphanumeric(11)
          # Parse the Medal TV URL
          uri = URI.parse(medal_tv_url)
          # Get response of the Medal TV URL
          response = Net::HTTP.get_response(uri)
          # Check if the response is successful
          if response.is_a?(Net::HTTPSuccess)
            # Get the content URL from the response body
            file_data = response.body
            # Get the content URL from the response body
            content_url = file_data.split('"contentUrl":"')[1]&.split('","')[0]
            # Check if the content URL exists
            if content_url
              # Parse the content URL
              uri = URI.parse(content_url)
              # Get response of the content URL
              response = Net::HTTP.get_response(uri)
              # Check if the response is successful
              if response.is_a?(Net::HTTPSuccess)
                # Get the file extension, local directory and local file path
                local_directory = "tmp/#{ticket}"
                FileUtils.mkdir_p(local_directory) unless File.directory?(local_directory)
                local_file_path = "tmp/#{ticket}/#{video_id}.mp4"
                # Write the file to the local directory
                File.open(local_file_path, 'wb') do |local_file|
                  local_file.write(response.body)
                end
                # Check file size and upload to S3 if over limit
                if File.size(local_file_path) < ENV["FILE_LIMIT"].to_i * 1024 * 1024
                  # Upload the file to the archive channel
                  uploaded_message = Bot.channel(ENV["EVIDENCE_CHANNEL_ID"]).send_file(File.open(local_file_path, 'rb'))
                  # Respond to ticket channel with link to archived file
                  event.channel.send_message("[Archived](#{uploaded_message.attachments.first.url})")
                  # Delete the local file
                  File.delete(local_file_path)
                else
                  # Upload to S3 and set content type
                  content_type = "video/mp4"
                  AutoArchive::S3.upload_to_s3(event, local_file_path, ticket, content_type)
                end
              else
                $logger.error "Failed to fetch Medal TV video content: #{response.code} #{response.message}"
                event.respond("Failed to archive Medal TV video, it may not be available yet. Please relink")
              end
            else
              event.respond("Failed to archive Medal TV video, it may not be available yet. Please relink")
            end
          else
            $logger.error "Failed to fetch Medal TV video page: #{response.code} #{response.message}"
            event.respond("Failed to archive Medal TV video, it may not be available yet. Please relink")
          end
        end
      end
    end
  end
end