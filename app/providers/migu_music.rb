# frozen_string_literal: true
class MiguMusic < BaseProvider
  SEARCH_BY_KEYWORD = "https://m.music.migu.cn/migu/remoting/scr_search_tag?type=2&keyword=%s&pgc=%s&rows=%s"
  GET_SONGS_API     = "http://music.migu.cn/v3/api/music/audioPlayer/songs?type=1"
  MUSIC_INFO_API    = "https://app.c.nf.migu.cn/MIGUM2.0/v2.0/content/querySongBySongId.do?contentId=0&songId=%s"
  LYRIC_API         = "http://music.migu.cn/v3/api/music/audioPlayer/getLyric?copyrightId=%s"
  SONG_URL_TEMP     = "https://app.pd.nf.migu.cn/MIGUM2.0/v1.0/content/sub/listenSong.do?contentId=%s&copyrightId=0&netType=01&resourceType=%s&toneFlag=%s&channel=0"
  SONG_PIC_API      = "http://music.migu.cn/v3/api/music/audioPlayer/getSongPic"
  TOPLIST_API       = "https://music.migu.cn/v3/music/top/%s"
  ARTIST_SONGS_API = "https://app.c.nf.migu.cn/MIGUM3.0/v1.0/template/singerSongs/release?templateVersion=2"
  DEFAULT_HEADERS = {
    "channel": "0",
    "Origin":  "http://music.migu.cn/v3",
    "Referer": "http://music.migu.cn/v3",
  }

  LYRIC_TIME_PATTERN = /\[(?<minute>\d{2}):(?<second>\d{2})\.(?<micro_second>\d{2})\]/

  BIT_RATE_MAP = {
    "64" =>  "LQ",
    "128" => "PQ",
    "320" => "HQ",
    "999" => "SQ",
  }

  class << self
    def defualt_headers
      DEFAULT_HEADERS
    end

    def search_music(keyword, page: 1, per_page: 30)
      headers = {
        "Origin":  "https://m.music.migu.cn",
        "Referer": "https://m.music.migu.cn",
      }
      reqeuest(SEARCH_BY_KEYWORD % [URI.encode_www_form_component(keyword), page, per_page], headers: headers).then(&method(:parse_json))
    end

    def artist_songs(artist_id, page: 1, per_page: 30)
      resp = reqeuest(ARTIST_SONGS_API, query: { singerId: artist_id, pageNo: page, pageSize: per_page }).then(&method(:parse_json))
      if resp["code"] != "000000"
        raise "Failed to get artist songs by id #{artist_id}, response: #{resp}"
      else
        resp.dig("data", "contentItemList", 0, "itemList")
      end
    end

    def song_info(mid)
      songId = mid
      if mid.starts_with?("6")
        fetchedSongId = reqeuest(GET_SONGS_API, query: { copyrightId: mid }).then(&method(:parse_json)).dig("items", 0, "songId")
        songId = fetchedSongId || mid
      end

      resp = reqeuest(MUSIC_INFO_API % [songId]).then(&method(:parse_json))
      if resp["code"] != "000000"
        raise "Failed to get song info by id #{mid}, response: #{resp}"
      else
        resp.dig("resource", 0)
      end
    end

    def song_lyrics(copyright_id)
      resp = reqeuest(LYRIC_API % [copyright_id]).then(&method(:parse_json))
      if resp["returnCode"] != "000000"
        raise "Failed to get song lyrics by id #{copyright_id}, response: #{resp}"
      else
        lyrics_content = resp.dig("lyric")
        lines = lyrics_content&.split("\r\n") || []
        lyrics_list = []

        lines.each do |line|
          line.scan(LYRIC_TIME_PATTERN).each do |group|
            lyrics_list << { time: group[0].to_i * 60000 + group[1].to_i * 1000 + group[2].to_i * 10, lyric: line.gsub(/(\[.*\])/, "").strip }
          end
        end

        lyrics_list.sort { |a, b| a[:time] <=> b[:time] }
      end
    end

    def song_url(content_id, bit_rate: 128)
      SONG_URL_TEMP % [content_id, "E", BIT_RATE_MAP[bit_rate.to_s] || "PQ"]
    end

    def toplist_songs(list_id = "migumusic")
      response = reqeuest(TOPLIST_API % [list_id])
      doc = Nokogiri::HTML.parse(response.body)
      scripts = doc.xpath("//script")
      JSON.parse(scripts[1]&.text&.gsub("var listData = ", "")).dig("songs", "items")
    end

    def song_pic_url(song_id)
      resp = reqeuest(SONG_PIC_API, query: { songId: song_id }).then(&method(:parse_json))
      if resp["returnCode"] != "000000"
        raise "Failed to get song picture by id #{song_id}, response: #{resp}"
      else
        url = resp.dig("largePic")
        if url&.starts_with?("//")
          "http:#{url}"
        else
          url
        end
      end
    end

    def create_song_from_data(migu_music = {}, skip_brackets: false, keep_ost: false, accompaniment: false, remove_brackets: false)
      if migu_music.nil?
        LOG.info "Song migu_music is empty, skipping..."
        return
      end

      model_keys_mapping = {
        musicid: [:id, :songId],
        artistid: :singerId,
        name: :songName,
        albumid: :albumId,
        artist: [:singerName, :singer],
        album: [:albumName, :album],
        copyrightid: :copyrightId
      }

      song_info = model_keys_mapping.keys.map do |key|
        if model_keys_mapping[key].is_a?(Array)
          val = model_keys_mapping[key].map do |k|
            migu_music[k.to_s]
          end.compact.first
          [key, val]
        else
          [key, migu_music[model_keys_mapping[key]&.to_s || "_____"]]
        end
      end.to_h.compact

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
        song = Song.create!(provider: :migu, **song_info)
        song.create_job!
      end
    rescue => e
      LOG.error "Failed to save migu music #{migu_music}, error: #{e.message}"
    end
  end
end