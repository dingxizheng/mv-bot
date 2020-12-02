# frozen_string_literal: true

require "dotenv/load"
require "fileutils"
require "logger"
require "rest-client"
require "faraday"
require "progress_bar"
require_relative "mongoid_config.rb"
require_relative "mongo_transaction.rb"
require_relative "video_maker.rb"
require_relative "youtube.rb"
require_relative "providers/kuwo_music.rb"
require_relative "providers/migu_music.rb"
require_relative "models/song.rb"
require_relative "models/music_job.rb"
require_relative "job_processors/base_processor.rb"
require_relative "job_processors/migu_downloader.rb"
require_relative "job_processors/video_processor.rb"
require_relative "job_processors/video_uploader.rb"

LOG = Logger.new(STDOUT)