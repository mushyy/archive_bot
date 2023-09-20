module DiscordEvidence 

  Bot.register_application_command(:ticketevidence , "Get large evidence files from archive") do |cmd|
    cmd.string(:ticket, "Ticket number to get evidence from", required: true)
  end

  Bot.application_command(:ticketevidence ) do |event|
    event.respond(content: "Attempting to fetch archived data", ephemeral: true)
    begin
      get_archived_data(event)

    rescue => e
      $logger.error "Error in storeticket command: #{e}"
      event.edit_response(content: "An error occurred while getting links.")
    end
  end

  def self.get_archived_data(event)
    ticket = event.options['ticket']
    match = ticket.match(ENV["TICKET_REGEX"])
    ticket = "#{ENV['TICKET_CHANNEL_PREFIX']}-#{match[1]}" if match
    
    s3 = Aws::S3::Client.new(
      access_key_id: ENV["S3_ACCESS_KEY_ID"],
      secret_access_key: ENV["S3_SECRET_ACCESS_KEY"],
      region: ENV["S3_REGION"],
      endpoint: ENV["S3_ENDPOINT"]
    )

    presigner = Aws::S3::Presigner.new(client: s3)

    resp = s3.list_objects_v2(bucket: ENV["S3_BUCKET_NAME"], prefix: "#{ticket}")

    begin
      if resp.contents.count > 0
        links = []
        resp.contents.each do |object|
          links << presigner.presigned_url(:get_object, bucket: ENV["S3_BUCKET_NAME"], key: object.key, expires_in: 604800)
        end
        message = "Links for #{ticket}:\nPlease note: These links will expire in 1 day. Bandwidth is expensive, please take care.
        \n
        #{links.join("\n")}"
        if message.length > 2000
          channel_id = Bot.user(event.user.id).pm.id
          links.each do |link|
            Bot.channel(channel_id).send_message(content: link)
          end
        else
          event.edit_response(content: message)
        end
      else
        event.edit_response(content: "No links found for ticket #{ticket}")
      end
    rescue StandardError => e
      $logger.error "An error occurred: #{e.message}"
      event.respond("An error occurred while generating links, please contact a developer")
    end    
  end
end
