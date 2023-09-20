require_relative 's3'
module AutoArchive
  module Streamable
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
        # Check if the message contains any Streamable URL
        streamable_url_matches = message.content.scan(%r{https://streamable\.com/\w+})
        # Loop through each Streamable URL
        streamable_url_matches.each do |streamable_url|
          # Get the video ID from the URL
          match_data = streamable_url.match(%r{https://streamable\.com/(\w+)})
          video_id = match_data[1]
          # Get the video info from the Streamable API
          api_url = "https://api.streamable.com/videos/#{video_id}"
          # Parse the API URL
          uri = URI.parse(api_url)
          # Get response of the API URL
          response = Net::HTTP.get_response(uri)
          # Check if the response is successful
          if response.is_a?(Net::HTTPSuccess)
            # Parse the response body as JSON
            video_data = JSON.parse(response.body)
            # Check if the video is ready
            if video_data["files"].nil?
              event.respond("File may not be ready yet, please try sending the URL again in a few minutes")
              next
            end
            # Get the download URL
            download_url = "#{video_data['files']['mp4']['url']}"
            # Parse the download URL from the API response
            uri = URI.parse(download_url)
            # Get response of the download URL
            response = Net::HTTP.get_response(uri)
            # Check if the response is successful
            if response.is_a?(Net::HTTPSuccess)
              # Get the file extension, local directory and local file path
              local_directory = "tmp/#{ticket}"
              # Create the local directory if it doesn't exist
              FileUtils.mkdir_p(local_directory) unless File.directory?(local_directory)
              local_file_path = "tmp/#{ticket}/#{File.basename(video_id)}.mp4"
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
              $logger.error "Failed to download Streamable video: #{response.code} #{response.message}"
            end
          else
            $logger.error "Failed to fetch Streamable video info: #{response.code} #{response.message}"
          end
        end
      end
    end
  end
end