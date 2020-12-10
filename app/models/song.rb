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

  field :english,             type: Boolean

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
    if is_english?
      <<~TXT
      If you like the video, please subscribe us at https://www.youtube.com/channel/UCMSUswyigS3R59TXLN2K_IA?view_as=subscriber

      #{song_lyrics.gsub("歌曲名", "SONG NAME").gsub("歌手名", "SINGER").gsub("作曲", "COMPOSER").gsub("作词", "LYRICIST")}

      **Disclaimer: This video is purely fan-made, if you (owners) want to remove this video, please CONTACT US DIRECTLY before doing anything. We will respectfully remove it**
      TXT
    else
      <<~TXT
      Welcome to subscribe us https://www.youtube.com/channel/UCMSUswyigS3R59TXLN2K_IA?view_as=subscriber

      #{song_lyrics}

      **該音樂版權為歌手及其音樂公司所有，本頻道僅提供推廣及宣傳只用，若喜歡他們的音樂請支持正版。如版權方認為該影片有侵權一事，請與本頻道聯繫，收到通知後將立即刪除，谢谢。**
      TXT
    end
  end

  def song_title
    if is_english?
      "#{artist} - #{name} (Unoffical Lyric Video)"
    else
      "#{artist} - #{name} (动态歌词)"
    end
  end

  def song_tags
    if is_english?
      ["Lyric", "Lyrics", title, artist, album]
    else
      ["华语", "经典", "歌词", "高清", title, artist, album]
    end
  end

  def song_lyrics
    lyrics_list.map { _1["lyric"] }.join("\n")
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

  def is_english?
    # [CLD.detect_language(song_lyrics), CLD.detect_language(title), CLD.detect_language(artist)].
    if CLD.detect_language(song_lyrics)[:name] == "ENGLISH"
      if CLD.detect_language(title)[:name] == "ENGLISH" || CLD.detect_language(title)[:name] == "Unknown"
        if CLD.detect_language(artist) == "Chinese" || CLD.detect_language(artist) == "Japanese"
          return false
        end
        true
      else
        false
      end
    else
      false
    end
  end
end