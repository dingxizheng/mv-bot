# frozen_string_literal: true

class UploadJob
  include Mongoid::Document
  include Mongoid::Timestamps

  field :last_run,                type: DateTime
  field :running,                 type: Boolean, default: false
  field :video_uploaded,          type: Boolean, default: false
  field :error,                   type: String

  field :platform,                type: String,  default: "youtube"
  # For youtube
  field :channel,                 type: String

  belongs_to :song, class_name:   "Song"
end