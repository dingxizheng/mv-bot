# frozen_string_literal: true

# docker run -d -p 4444:4444 --shm-size 2g -v /Users/eding/Documents/projects/my-video-app/downloads:/video/files selenium/standalone-chrome
# docker run -it --shm-size 2g --env REMOTE_SELENIUM_URL=http://192.168.68.112:4444/wd/hub -v /Users/eding/Documents/projects/my-video-app/downloads:/video/files music_video_bot:latest
data = {
  title: "Mojito 周杰伦",
  description: "Mojito \n 周杰伦",
  video: "/Users/eding/Documents/projects/my-video-app/downloads/142655450_video.mp4",
  kids: false,
  tags: "周杰伦, 华语",
  publish_type: "PUBLIC"
}
Youtube.upload_video(**data)

data = {
  title: "Mojito 周杰伦",
  description: "Mojito \n 周杰伦",
  video: "/video/files/142655450_video.mp4",
  kids: false,
  tags: "周杰伦, 华语",
  publish_type: "PUBLIC"
}

image_file = "../downloads/142655450_cover.jpg"
blured_image_file = "../downloads/142655450_cover_blured.jpg"

MiniMagick::Tool::Convert.new do |convert|
  convert << image_file << "-channel" << "RGBA" << "-blur" << "0x8"
  convert << "-resize" << "1280x"
  convert << "-gravity" << "center" << "-crop" << "16:9" << "+repage"
  # convert << "-pointsize" << "24" << "label:'周杰伦'"

  convert.stack do |stack|
    stack << image_file
    stack << "-resize" << "320x"
  end

  convert << "-geometry" << "+260-0" << "-composite"

  convert << blured_image_file
end

MiniMagick::Tool::Convert.new do |convert|
  convert << blured_image_file

  convert.stack do |stack|
    stack << "-size" << "500x"
    stack << "-background" << "none"
    stack << "-gravity" << "west"
    stack << "-fill" << "white"
    stack << "-font" << "ShangShouDunHeiTi-2.ttf"
    stack << "-pointsize" << "50"
    stack << "caption:周杰伦\n\n断了的弦"

    stack.stack do |stack2|
      stack2 << "+clone"
      stack2 << "-background" << "black"
      stack2 << "-shadow" << "80x3+4+4"
    end

    stack << "+swap" << "-background" << "none" << "-layers" << "merge" << "+repage"

    stack << "-geometry" << "+200+0"
  end

  convert << "-composite"
  convert << "../downloads/142655450_cover_blured_text.jpg"
end