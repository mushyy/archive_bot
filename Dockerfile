FROM ruby:3.2.2

# Install dependencies
RUN apt-get update -qq && apt-get install -y build-essential libpq-dev software-properties-common python3-launchpadlib python3-setuptools python3-pip python3-dev ffmpeg

RUN apt update && add-apt-repository ppa:tomtomtom/yt-dlp && apt update && apt install -y yt-dlp

WORKDIR /app
COPY . /app

RUN bundle install