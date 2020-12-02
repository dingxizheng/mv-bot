# frozen_string_literal: true

class Song
  include Mongoid::Document
  include Mongoid::Timestamps

  field :musicid,             type: String
  field :copyrightid,         type: String
  field :name,                type: String, as: :title
  field :albumid,             type: String
  field :album,               type: String
  field :artist,              type: String
  field :artistid,            type: String
  field :release_date,        type: Date
  field :albumpic,            type: String
  field :lyrics_list,         type: Array
  field :lyrics_description,  type: String
  field :provider,            type: String

  field :contentid,           type: String
  field :mp3_url,             type: String
  field :pic_url,             type: String

  def self.create_from_info(input)
    song = Song.new
    input.each do |k, v|
      song.send("#{k.underscore}=", v) if Song.attribute_names.include?(k.underscore)
    end
    song
  end

  # def name=(value = "")
  #   self[:name] = value.gsub(/\(.*?\)/, "").strip
  # end

  def clean_name
    name.gsub(/\(.*?\)/, "").gsub(/（.*）/, "").strip
  end

  def song_description
    <<~TXT
    Welcome to subscribe us https://www.youtube.com/channel/UCMSUswyigS3R59TXLN2K_IA?view_as=subscriber

    #{lyrics_list.map { _1["lyric"] }.join("\n")}\n

    **該音樂版權為歌手及其音樂公司所有，本頻道僅提供推廣及宣傳只用，若喜歡他們的音樂請支持正版。如版權方認為該影片有侵權一事，請與本頻道聯繫，收到通知後將立即刪除，谢谢。**
    TXT
  end

  def create_job!
    MusicJob.create!(song: self)
  end

  def disk_location
    ENV["APP_WORKPATH"] || "../downloads"
  end

  def music_folder_path
    path = File.join(disk_location, "songs", id.to_s)
    FileUtils.mkdir_p(path)
    path
  end

  def audio_file_path
    File.join(music_folder_path, "#{musicid}.mp3")
  end

  def video_file_path(relative: false)
    if !relative
      File.join(music_folder_path, "#{musicid}_video.mp4")
    else
      File.join("songs", id.to_s, "#{musicid}_video.mp4")
    end
  end

  def ass_file_path
    File.join(music_folder_path, "#{musicid}_ass.ass")
  end

  def cover_file_path
    File.join(music_folder_path, "#{musicid}_cover.jpg")
  end

  def video_cover_file_path
    File.join(music_folder_path, "#{musicid}_video_cover.jpg")
  end
end