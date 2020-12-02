# frozen_string_literal: true

class KuwoMusic
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
    def reqeuest(url)
      RestClient.get(url, { accept: :json, **DEFAULT_HEADERS })
    end

    def download_file(url, output:)
      LOG.info "Downloading #{url}, output: #{output}"
      File.open(output, "w") do |file|
        block = proc do |response|
          file_size = response.content_length
          progress_bar = ProgressBar.new(file_size / 1024 / 1024)
          response.read_body do |chunk|
            progress_bar.increment!(chunk.size / 1024 / 1024) rescue nil
            file.write(chunk)
          end
        end
        RestClient::Request.execute(method: :get, url: url, headers: DEFAULT_HEADERS, block_response: block, timeout: 200)
      end
    end

    def parse_json(response)
      JSON.parse(response.body)
    end

    def search_music(keyword)
      reqeuest(SEARCH_BY_KEYWORD % [URI.encode_www_form_component(keyword)]).then(&method(:parse_json)).dig("data")
    end

    def song_info(mid)
      # %{
      #   根据mid也就是rid，获取音乐信息
      #   经过筛选后的数据格式
      #   musicrid: "MUSIC_81010978"
      #   artist: "海伦"
      #   pic: "http://img2.kuwo.cn/star/albumcover/300/48/79/1272165134.jpg"
      #   isstar: 0
      #   rid: 81010978
      #   upPcStr: "kuwo://play/?play=MQ==&num=MQ==&musicrid0=TVVTSUNfODEwMTA5Nzg=&name0=x8Wx37nDxO8=&artist0=uqPC1w==&album0=x8Wx37nDxO8=&artistid0=MTA4MDAzMA==&albumid0=MTEzNzE4MjU=&playsource=d2ViwK3G8L/Nu6e2yy0+MjAxNrDmtaXH+tKz"
      #   duration: 183
      #   content_type: "0"
      #   mvPlayCnt: 451286
      #   track: 1
      #   hasLossless: true
      #   hasmv: 1
      #   releaseDate: "2019-11-09"
      #   album: "桥边姑娘"
      #   albumid: 11371825
      #   pay: "16515324"
      #   artistid: 1080030
      #   albumpic: "http://img2.kuwo.cn/star/albumcover/500/48/79/1272165134.jpg"
      #   songTimeMinutes: "03:03"
      #   isListenFee: false
      #   mvUpPcStr: "kuwo://play/?play=MQ==&num=MQ==&musicrid0=TVVTSUNfODEwMTA5Nzg=&name0=x8Wx37nDxO8=&artist0=uqPC1w==&album0=x8Wx37nDxO8=&artistid0=MTA4MDAzMA==&albumid0=MTEzNzE4MjU=&playsource=d2ViwK3G8L/Nu6e2yy0+MjAxNrDmtaXH+tKz&media=bXY="
      #   pic120: "http://img2.kuwo.cn/star/albumcover/120/48/79/1272165134.jpg"
      #   albuminfo: "海伦 最新单曲《桥边姑娘》。"
      #   name: "桥边姑娘"
      #   online: 1
      #   payInfo: {cannotOnlinePlay: 0, cannotDownload: 0}
      # }

      reqeuest(MUSIC_INFO_API % [mid]).then(&method(:parse_json)).dig("data")
    end

    def song_lyrics(mid)
      sleep(rand(1..7)) # 访问太快，会出现500的错误
      reqeuest(SONG_LYRICS % [mid]).then(&method(:parse_json)).dig("data", "lrclist")
    end

    def music_toplists
      # %{
      #   获取所有的音乐榜单信息
      #   经过筛选后的数据格式
      #   [
      #       name: "官方榜",
      #       list: Array[5]
      #           {
      #               "sourceid":"93",
      #               "intro":"酷我用户每天播放线上歌曲的飙升指数TOP排行榜，为你展示流行趋势、蹿红歌曲，每天更新",
      #               "name":"酷我飙升榜",
      #               "id":"489929",
      #               "source":"2",
      #               "pic":"http://img3.kwcdn.kuwo.cn/star/upload/7/8/1584054363.png",
      #               "pub":"今日更新"
      #           },
      #   ]
      # }
      reqeuest(TOP_LIST).then(&method(:parse_json)).dig("data")
    end

    def toplist_songs(list_id, page: 1, per_page: 30)
      # %{
      #   根据榜单bangid, 获取音乐列表
      #   经过筛选后的数据格式
      #   num: "300" 这个榜单的总的歌词的数量，可以依据这个实现榜单所有歌词的爬取
      #   pub: "2020-03-13"
      #   musicList: [{musicrid: "MUSIC_80488731", artist: "阿冗", trend: "u0",…},…]
      # }
      reqeuest(MUST_LIST % [list_id, page, per_page]).then(&method(:parse_json)).dig("data")
    end

    def artist_songs(artist_id, page: 1, per_page: 30)
      reqeuest(ARTIST_SONGS % [artist_id, page, per_page]).then(&method(:parse_json)).dig("data")
    end

    def mp3_download_url_by_rid(mid)
      mp3_url = MP3_URL % [mid]
      reqeuest(mp3_url).then(&method(:parse_json)).dig("url")
    end

    def download_song_by_id(mid, path:)
      mp3_url = mp3_download_url_by_rid(mid)
      info    = song_info(mid)
      cover_url = (info["albumpic"] || info["pic"]).gsub(/albumcover\/\d+/, "albumcover/1000")

      # Download mp3 file
      download_file(mp3_url, output: "#{path}/#{mid}.mp3")
      LOG.info "#{path}/#{mid}.mp3 downloaded."
      # Download cover file
      download_file(cover_url, output: "#{path}/#{mid}_cover.jpg")
      LOG.info "#{path}/#{mid}_cover.jpg downloaded."
      # Download ass file
      download_lyrics(mid, path: path)
    end

    def download_lyrics(mid, path:)
      # Download ass file
      lyrics = song_lyrics(mid)
      write_ass_file(lyrics, path: "#{path}/#{mid}_ass.ass")
      LOG.info "#{path}/#{mid}_ass.ass downloaded."
    end

    def write_ass_file(lyrics = [], path:)
      lines = lyrics.map.with_index do |line, index|
        start_time = line["time"]
        text = line["lineLyric"]
        start_seconds, start_milliseconds = start_time.split(".").map(&:to_i)

        start_hour, start_minute, start_second = seconds_to_hour_minute_second(start_seconds)

        end_time = lyrics[index + 1]&.[]("time") || "10000.00"
        end_seconds, end_milliseconds = end_time.split(".").map(&:to_i)
        end_hour, end_minute, end_second = seconds_to_hour_minute_second(end_seconds)

        "Dialogue: 0,#{start_hour}:#{"%02d" % start_minute}:#{"%02d" % start_second}.#{"%02d" % start_milliseconds.to_s[0..1].to_i},#{end_hour}:#{"%02d" % end_minute}:#{"%02d" % end_second}.#{"%02d" % end_milliseconds.to_s[0..1].to_i},*Default,NTP,0000,0000,0000,,#{text}"
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

    def seconds_to_hour_minute_second(seconds)
      start_hour = seconds / 3600
      start_minute = (seconds - start_hour * 3600) / 60
      start_second = seconds - start_hour * 3600 - start_minute * 60
      [start_hour, start_minute, start_second]
    end
  end
end