# frozen_string_literal: true

class MusicJob
  include Mongoid::Document
  include Mongoid::Timestamps

  field :last_run,  type: DateTime
  field :running,   type: Boolean, default: false

  field :mp3_downloaded,          type: Boolean, default: false
  field :cover_downloaded,        type: Boolean, default: false
  field :video_cover_generated,   type: Boolean, default: false
  field :ass_subtitles_generated, type: Boolean, default: false
  field :video_generated,         type: Boolean, default: false
  field :video_uploaded,          type: Boolean, default: false

  field :error,                   type: String

  belongs_to :song, class_name:   "Song"
end