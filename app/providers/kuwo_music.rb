# frozen_string_literal: true

class KuwoMusic < BaseProvider
  MUSIC_INFO_API    = "http://www.kuwo.cn/api/www/music/musicInfo?mid=%s"
  SEARCH_BY_KEYWORD = "http://www.kuwo.cn/api/www/search/searchMusicBykeyWord?key=%s"
  MP3_URL           = "http://www.kuwo.cn/url?rid=%s&type=convert_url3&br=128kmp3"
  SONG_LYRICS       = "http://www.kuwo.cn/newh5/singles/songinfoandlrc?musicId=%s"
  ARTIST_SONGS      = "http://www.kuwo.cn/api/www/artist/artistMusic?artistid=%s&pn=%s&rn=%s"
  TOP_LIST          = "http://www.kuwo.cn/api/www/bang/bang/bangMenu"
  MUST_LIST         = "http://www.kuwo.cn/api/www/bang/bang/musicList?bangId=%s&pn=%s&rn=%s"
  INVALID_CHARS     = "/^.*(\\|\/)/"

  DEFAULT_HEADERS   = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/79.0.3945.130 Safari/537.36",
    "Referer": "http://www.kuwo.cn/search/list", # 这个请求头没有的话，会出现 403 Forbidden
    "csrf": "0HQ0UGKNAKR", # CSRF Token Not Found!
    # CSRF Token Not Found!
    "Cookie": "kw_token=0HQ0UGKNAKR;",
  }

  class << self
    def defualt_headers
      DEFAULT_HEADERS
    end

    def search_music(keyword)
      reqeuest(SEARCH_BY_KEYWORD % [URI.encode_www_form_component(keyword)]).then(&method(:parse_json)).dig("data")
    end

    def song_info(mid)
      reqeuest(MUSIC_INFO_API % [mid]).then(&method(:parse_json)).dig("data")
    end

    def song_lyrics(mid)
      sleep(rand(1..2)) # 访问太快，会出现500的错误
      lyrics = reqeuest(SONG_LYRICS % [mid]).then(&method(:parse_json)).dig("data", "lrclist")
      lyrics.map.with_index do |line, _index|
        start_time = line["time"]
        text = line["lineLyric"]
        seconds, milliseconds = start_time.split(".")
        { lyric: text, time: (seconds.to_i * 1000 + "0.#{milliseconds}".to_f * 1000).to_i }
      end
    end

    def music_toplists
      reqeuest(TOP_LIST).then(&method(:parse_json)).dig("data")
    end

    def toplist_songs(list_id, page: 1, per_page: 30)
      reqeuest(MUST_LIST % [list_id, page, per_page]).then(&method(:parse_json)).dig("data")
    end

    def artist_songs(artist_id, page: 1, per_page: 30)
      reqeuest(ARTIST_SONGS % [artist_id, page, per_page]).then(&method(:parse_json)).dig("data")
    end

    def song_url(mid)
      mp3_url = MP3_URL % [mid]
      reqeuest(mp3_url).then(&method(:parse_json)).dig("url")
    end

    def create_song_from_data(kuwo_music = {}, skip_brackets: false, keep_ost: false, accompaniment: false, remove_brackets: false)
      if kuwo_music.nil?
        LOG.info "Song kuwo_music is empty, skipping..."
        return
      end

      model_keys_mapping = {
        musicid: :rid,
        artistid: :artistid,
        name: :name,
        albumid: :albumid,
        artist: :artist,
        album: :album
      }

      song_info = model_keys_mapping.keys.map do |key|
        if model_keys_mapping[key].is_a?(Array)
          val = model_keys_mapping[key].map do |k|
            kuwo_music[k.to_s]
          end.compact.first
          [key, val]
        else
          [key, kuwo_music[model_keys_mapping[key]&.to_s || "_____"]]
        end
      end.to_h.compact

      cover_url = (kuwo_music["albumpic"] || kuwo_music["pic"]).gsub(/albumcover\/\d+/, "albumcover/1000")
      song_info[:pic_url] = cover_url

      if !accompaniment && song_info[:name].include?("伴奏")
        LOG.info "Song name contains 伴奏, skipping..."
        return
      end

      if !Song.find_by(musicid: song_info["musicid"]).nil?
        LOG.info "Song #{song_info[:name]} exists, skipping..."
        return
      end

      if skip_brackets && song_info[:name]&.gsub(/\(.*?\)/, "")&.gsub(/（.*）/, "")&.strip != song_info[:name]
        LOG.info "Song name #{song_info[:name]} contains brackets, skipping..."
        return
      end

      # if song_info[:artist]&.size&.>(20)
      #   LOG.info "Artist name #{song_info[:artist]} is too long, skipping..."
      #   return
      # end

      LOG.info "Song name good, #{song_info[:name]}"

      if remove_brackets
        song_info[:name] = song_info[:name].gsub(/\(.*?\)/, "").gsub(/（.*）/, "").strip
      end

      MongoTransaction.start(log: true) do
        song = Song.create!(provider: :kuwo, **song_info)
        song.create_job!
      end
    rescue => e
      LOG.error "Failed to save kuwo music #{kuwo_music}, error: #{e.message}"
    end
  end
end