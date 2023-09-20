module AutoArchive
  module S3
    def self.upload_to_s3(event, local_file_path, ticket, content_type)
      begin
        # Create S3 client
        s3 = Aws::S3::Client.new(
          access_key_id: ENV["S3_ACCESS_KEY_ID"],
          secret_access_key: ENV["S3_SECRET_ACCESS_KEY"],
          region: ENV["S3_REGION"],
          endpoint: ENV["S3_ENDPOINT"]
          )
          # Open local file and upload to S3
          File.open(local_file_path, 'rb') do |file|
            s3.put_object(bucket: ENV["S3_BUCKET_NAME"], key: "#{ticket}/#{Date.today.strftime('%d_%m_%Y')}/#{File.basename(local_file_path)}", body: file, content_type: content_type)
          end
          # If S3 is public give public link, otherwise tell user to use the lookup command
          if ENV["S3_PUBLIC"]&.downcase == 'true'
            event.channel.send_message("[Archived](#{ENV["S3_ENDPOINT"]}/#{ENV["S3_BUCKET_NAME"]}/#{ticket}/#{Date.today.strftime('%d_%m_%Y')}/#{File.basename(local_file_path)})")
          else
            event.channel.send_message("Large file was shipped to archived storage. \nPlease use the look up command to get the link(s) in the future `/ticketevidence #{ticket}`")
          end
      rescue => e
        $logger.error "Error in upload_to_s3: #{e}"
        event.channel.send_message("An error occurred while uploading the file")
      end
      # Delete the local file
      File.delete(local_file_path)
    end
  end
end