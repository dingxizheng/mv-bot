# frozen_string_literal: true
class MiguMusic
  SEARCH_BY_KEYWORD = "https://m.music.migu.cn/migu/remoting/scr_search_tag?type=2&keyword=%s&pgc=%s&rows=%s"
  MUSIC_INFO_API    = "https://app.c.nf.migu.cn/MIGUM2.0/v2.0/content/querySongBySongId.do?contentId=0&songId=%s"
  LYRIC_API         = "http://music.migu.cn/v3/api/music/audioPlayer/getLyric?copyrightId=%s"
  SONG_URL_TEMP     = "https://app.pd.nf.migu.cn/MIGUM2.0/v1.0/content/sub/listenSong.do?contentId=%s&copyrightId=0&netType=01&resourceType=%s&toneFlag=%s&channel=0"
  SONG_PIC_API      = "http://music.migu.cn/v3/api/music/audioPlayer/getSongPic"

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
    def reqeuest(url, query: {}, headers: {})
      LOG.info "Requesting url: #{url}, query: #{query}"
      RestClient.get(url, { accept: :json, params: query, **DEFAULT_HEADERS, **headers })
    end

    def download_file(url, output:)
      LOG.info "Downloading #{url}, output: #{output}"
      rs = File.open(output, "w") do |file|
        block = proc do |response|
          if response.code.starts_with?("3")
            File.delete(output)
            LOG.info "Redirect to #{url}"
            return download_file(response.header["location"], output: output)
          end
          file_size = response.content_length || 0
          progress_bar = ProgressBar.new(file_size / 1024 / 1024)
          response.read_body do |chunk|
            progress_bar.increment!(chunk.size / 1024 / 1024) rescue nil
            file.write(chunk)
          end
        end
        RestClient::Request.execute(method: :get, url: url, headers: DEFAULT_HEADERS, block_response: block, timeout: 200, max_redirects: 5)
      end

      if !rs.code.starts_with?("2")
        raise "Failed to download file from url: #{url}"
      end
    end

    def parse_json(response)
      JSON.parse(response.body)
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
      resp = reqeuest(MUSIC_INFO_API % [mid]).then(&method(:parse_json))
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

    def lyrics_to_ass_file(lyrics = [], path:)
      lines = lyrics.map.with_index do |line, index|
        start_time = line[:time]
        text = line[:lyric]
        start_hour, start_minute, start_second, start_micro_second = seconds_to_hour_minute_second(start_time)

        end_time = lyrics[index + 1]&.[](:time) || 10_000_000
        end_hour, end_minute, end_second, end_micro_second = seconds_to_hour_minute_second(end_time)

        "Dialogue: 0,#{start_hour}:#{"%02d" % start_minute}:#{"%02d" % start_second}.#{"%02d" % start_micro_second},#{end_hour}:#{"%02d" % end_minute}:#{"%02d" % end_second}.#{"%02d" % end_micro_second},*Default,NTP,0000,0000,0000,,#{text}"
      end

      content = <<~ASS
      [V4+ Styles]
      Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
      Style: Default,Arial,20,&H00FFFFFF,&HF0000000,&H00000000,&HF0000000,1,0,0,0,100,100,0,0.00,1,1,0,2,30,30,10,134

      [Events]
      Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
      #{lines.join("\n")}
      ASS

      File.write(path, content)
    end

    def song_url(content_id, bit_rate: 128)
      SONG_URL_TEMP % [content_id, "E", BIT_RATE_MAP[bit_rate.to_s] || "PQ"]
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

    def migu_to_song_model(migu_music = {}, skip_brackets: false)
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

      if !Song.find_by(musicid: song_info["musicid"]).nil?
        LOG.info "Song #{song_info[:name]} exists, skipping..."
        return
      end

      if skip_brackets && song_info[:name]&.gsub(/\(.*?\)/, "")&.gsub(/（.*）/, "")&.strip != song_info[:name]
        LOG.info "Song name #{song_info[:name]} contains brackets, skipping..."
        return
      end

      LOG.info "Song name good, #{song_info[:name]}"

      MongoTransaction.start(log: true) do
        song = Song.create!(provider: :migu, **song_info)
        song.create_job!
      end
    rescue => e
      LOG.error "Failed to save migu music #{migu_music}, error: #{e.message}"
    end

    private
      def seconds_to_hour_minute_second(milliseconds)
        start_hour = milliseconds / 3600 / 1000
        start_minute = (milliseconds - start_hour * 3600 * 1000) / 60 / 1000
        start_second = (milliseconds - start_hour * 3600 * 1000 - start_minute * 60 * 1000) / 1000
        micro_second = milliseconds - start_hour * 3600 * 1000 - start_minute * 60 * 1000 - start_second * 1000
        [start_hour, start_minute, start_second, micro_second / 10]
      end
  end
end