# frozen_string_literal: true

class BaseProvider
  class << self
    def defualt_headers
      {}
    end

    def reqeuest(url, query: {}, headers: {})
      LOG.info "Requesting url: #{url}, query: #{query}"
      RestClient.get(url, { accept: :json, params: query, **defualt_headers, **headers })
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
        RestClient::Request.execute(method: :get, url: url, headers: defualt_headers, block_response: block, timeout: 200, max_redirects: 5)
      end

      if !rs.code.starts_with?("2")
        raise "Failed to download file from url: #{url}"
      end
    end

    def parse_json(response)
      JSON.parse(response.body)
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

    def seconds_to_hour_minute_second(milliseconds)
      start_hour = milliseconds / 3600 / 1000
      start_minute = (milliseconds - start_hour * 3600 * 1000) / 60 / 1000
      start_second = (milliseconds - start_hour * 3600 * 1000 - start_minute * 60 * 1000) / 1000
      micro_second = milliseconds - start_hour * 3600 * 1000 - start_minute * 60 * 1000 - start_second * 1000
      [start_hour, start_minute, start_second, micro_second / 10]
    end
  end
end