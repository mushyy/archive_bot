require_relative 's3'
module AutoArchive
  module Gyazo
    Bot.channel_create do |event|
      # Check if the channel name starts with "ticket"
      if event.channel.name.downcase.start_with?(ENV["TICKET_CHANNEL_PREFIX"].downcase)
        # Start listening for messages in the newly created channel
        start_listening_in_channel(event.channel)
      end
    end
    # Function to start listening for messages in a specific channel
    def self.start_listening_in_channel(channel)
      Bot.message(in: channel) do |event|
        # Get message from event
        message = event.message
        # Check if the message contains any Gyazo URL
        gyazo_url_matches = message.content.scan(%r{https://gyazo\.com/\w+})
        # Loop through each Gyazo URL
        gyazo_url_matches.each do |gyazo_url|
          # Get the image\video ID from the URL
          match_data = gyazo_url.match(%r{https://gyazo\.com/(\w+)})
          # Get the image\video ID from the URL
          image_id = match_data[1]
          # Get the image\video info from the Gyazo API (oEmbed)
          api_url = "https://api.gyazo.com/api/oembed?url=#{gyazo_url}"
          # Parse the API URL
          uri = URI.parse(api_url)
          # Get response of the API URL
          response = Net::HTTP.get_response(uri)
          # Check if the response is successful
          if response.is_a?(Net::HTTPSuccess)
            # Parse the response body as JSON
            image_data = JSON.parse(response.body)
            # Check content type if video or image
            content_type = image_data['type']
            # Handle Gyazo videos
            if content_type == 'video'
              # Get the video URL as MP4
              video_url = "https://i.gyazo.com/#{image_id}.mp4"
              # Parse the video URL
              uri = URI.parse(video_url)
              # Get response of the video URL
              response = Net::HTTP.get_response(uri)
              # Check if the response is successful
              if response.is_a?(Net::HTTPSuccess)
                # Get the file extension, local directory and local file path
                local_directory = "tmp/#{ticket}"
                # Create the local directory if it doesn't exist
                FileUtils.mkdir_p(local_directory) unless File.directory?(local_directory)
                file_extension = File.extname(video_url)
                local_file_path = "tmp/#{ticket}/#{File.basename(image_id)}#{file_extension}"
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
                $logger.error "Gyazo Video Failure: #{response.code} #{response.message}"
                event.respond("Failed to archive Gyazo video, please retry linking it or uploading it as an attachment")
              end
            else
              # Handle Gyazo images
              image_url = image_data['url']
              # Parse the image URL
              uri = URI.parse(image_url)
              # Get response of the image URL
              response = Net::HTTP.get_response(uri)
              # Check if the response is successful
              if response.is_a?(Net::HTTPSuccess)
                # Get the file extension, local directory and local file path
                local_directory = "tmp/#{ticket}"
                # Create the local directory if it doesn't exist
                FileUtils.mkdir_p(local_directory) unless File.directory?(local_directory)
                file_extension = File.extname(image_url)
                local_file_path = "tmp/ticket-#{ticket}/#{File.basename(image_id)}#{file_extension}"
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
                  content_type = "image/#{file_extension[1..-1]}"
                  AutoArchive::S3.upload_to_s3(event, local_file_path, ticket, content_type)
                end
              else
                $logger.error "Gyazo Image Failure: #{response.code} #{response.message}"
                event.respond("Failed to archive Gyazo image, please retry linking it or uploading it as an attachment")
              end
            end
          else
            $logger.error "Gyazo Generic Failure: #{response.code} #{response.message}"
            event.respond("Failed to archive from Gyazo please retry linking it or uploading it as an attachment")
          end
        end
      end
    end
  end
end