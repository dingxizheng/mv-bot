# frozen_string_literal: true
require "mini_magick"

class VideoMaker
  # `-crf <value>` video quality
  # `-b:a <value>` audio bitrates
  # `-b:v <value>` video bitrates
  # `-c:v <value>`  video codec
  # `-c:a <value>`  audio codec
  # `-filter:v ...` video filter

  VIDEO_RESOLUTION = 1280
  WAVE_HEIGHT = 100
  WAVE_SIZE = "#{VIDEO_RESOLUTION}x#{WAVE_HEIGHT}"

  FFMPEG_COMMAND_WITH_WAVES = <<-SHELL
    ffmpeg -y -i '%{audio}' -loop 1 -i '%{cover}' \
    -filter_complex "[0:a]showwaves=mode=line:s=#{WAVE_SIZE}:colors=White@0.5[v];[1:v][v]overlay=x=0:y=#{720 - WAVE_HEIGHT / 2}[outv]" -map "[outv]" -pix_fmt yuv420p \
    -map 0:a -c:v libx264 -c:a copy -shortest '%{output}'
  SHELL

  FFMPEG_COMMAND_BURN_SUBTITLES = "ffmpeg -i '%{input}' -vf \"ass='%{ass}'\" -max_muxing_queue_size 9999 '%{output}'"

  class << self
    def make_video(audio:, cover:, output:)
      result = system(FFMPEG_COMMAND_WITH_WAVES % { audio: audio, cover: cover, output: output })
      result
    end

    def burn_subtitles(input:, output:, ass:)
      result = system(FFMPEG_COMMAND_BURN_SUBTITLES % { input: input, ass: ass, output: output })
      result
    end

    def make_video_with_subtitles(audio:, cover:, output:, ass:)
      tmp_video_name = "#{File.basename(output, File.extname(output))}_tmp_video#{File.extname(output)}"
      make_video(audio: audio, cover: cover, output: tmp_video_name)
      burn_subtitles(input: tmp_video_name, output: output, ass: ass)
      File.delete(tmp_video_name)
    end

    def make_cover_image(input:, output:, artist:, title:)
      tmp_image_name = "#{File.basename(input, File.extname(input))}_1280x720#{File.extname(input)}"
      # image = MiniMagick::Image.open(input)
      width = VIDEO_RESOLUTION
      height = VIDEO_RESOLUTION / 16 * 9
      MiniMagick::Tool::Convert.new do |convert|
        convert << input << "-channel" << "RGBA" << "-blur" << "0x8"
        convert << "-fill" << "black" << "-colorize" << "30%"
        convert << "-resize" << "#{VIDEO_RESOLUTION}x"
        convert << "-gravity" << "center" << "-crop" << "#{width}x#{height}+0+0" << "+repage"

        convert.stack do |stack|
          stack  << input
          stack  << "-resize" << "280x"
        end

        convert << "-geometry" << "-330-20" << "-composite"
        convert << tmp_image_name
      end

      MiniMagick::Tool::Convert.new do |convert|
        convert << tmp_image_name
        convert.stack do |stack|
          stack << "-size" << "700x"
          stack << "-background" << "none"
          stack << "-gravity" << "west"
          stack << "-fill" << "white"
          stack << "-font" << "ShangShouDunHeiTi-2.ttf"
          stack << "-pointsize" << "100"
          stack << "caption:#{artist}\n#{title}"

          stack.stack do |stack2|
            stack2 << "+clone"
            stack2 << "-background" << "black"
            stack2 << "-shadow" << "80x3+4+4"
          end

          stack << "+swap" << "-background" << "none" << "-layers" << "merge" << "+repage"
          stack << "-geometry" << "+500-20"
        end
        convert << "-composite"
        convert << output
      end

      File.delete(tmp_image_name)
    end
  end
end