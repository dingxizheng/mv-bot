# frozen_string_literal: true

require "dotenv/load"
require "fileutils"
require "logger"
require "rest-client"
require "faraday"
require "progress_bar"
require "nokogiri"
require "cld"
require_relative "mongoid_config.rb"
require_relative "mongo_transaction.rb"
require_relative "video_maker.rb"
require_relative "websites/youtube.rb"
require_relative "providers/base_provider.rb"
require_relative "providers/kuwo_music.rb"
require_relative "providers/migu_music.rb"
require_relative "models/song.rb"
require_relative "models/music_job.rb"
require_relative "job_processors/base_processor.rb"
require_relative "job_processors/music_downloader.rb"
require_relative "job_processors/video_processor.rb"
require_relative "job_processors/video_uploader.rb"

LOG = Logger.new(STDOUT)

def upload_music(id, provider: :migu)
  if provider == :migu
    song = MiguMusic.song_info(id)
    if !song.nil?
      MiguMusic.create_song_from_data(song)
    end
  elsif provider == :kuwo
    song = KuwoMusic.song_info(id)
    if !song.nil?
      KuwoMusic.create_song_from_data(song)
    end
  end
end