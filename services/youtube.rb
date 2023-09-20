require_relative 's3'
module AutoArchive
  module Youtube
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
        # Check if the message contains any YouTube URL (shortened or not)
        youtube_url_matches = message.content.scan(%r{(https?://(?:www\.)?youtu\.be/[^\s]+|https?://(?:www\.)?youtube\.com/watch\?v=[^\s]+|https?://(?:www\.)?youtube\.com/clip/[^\s]+)})
        # Loop through each YouTube URL
        youtube_urls = youtube_url_matches.flatten
        youtube_urls.each do |youtube_url|
          begin
            # Get the file extension, local directory and local file path
            local_directory = "tmp/#{ticket}"
            # Create the local directory if it doesn't exist
            FileUtils.mkdir_p(local_directory) unless File.directory?(local_directory)
            video_id = SecureRandom.alphanumeric(11)
            # Create the command using yt-dlp, should be installed on the system
            command = "yt-dlp -q -o tmp/#{ticket}/#{video_id}.mp4 #{youtube_url} -S ext"
            # Execute the command
            system(command)
            # Get the file extension, local directory and local file path
            local_file_path = "tmp/#{ticket}/#{video_id}.mp4"
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
          rescue => e
            $logger.error "Error in youtube-dl: #{e}"
            event.respond("An error occurred while archiving the video, please check the logs")
          end
        end
      end
    end
  end
end