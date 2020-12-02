



ffmpeg -loop 1 -framerate 24 -i '142655450_cover_blured_text.jpg' -i '142655450.mp3' \
  -c:v libx265 -preset veryslow -c:a copy -shortest '142655450_video_test.mp4'

ffmpeg -i '142655450_video_test.mp4' \
-filter_complex "[0:a]showwaves=mode=line:s=1280x200:colors=White[v];[0:v][v]overlay[outv]" -map "[outv]" -pix_fmt yuv420p \
-c:v libx264 -c:a copy  -max_muxing_queue_size 9999 '142655450_video_waves.mp4'

ffmpeg -y -i '142655450.mp3' -loop 1 -i '142655450_cover_blured_text.jpg' \
-filter_complex "[0:a]showwaves=mode=line:s=1280x100:colors=White[v];[1:v][v]overlay[outv]" -map "[outv]" -pix_fmt yuv420p \
-map 0:a -c:v libx264 -c:a copy -shortest '142655450_video_test.mp4'

=>541514

853270
docker run -it -v /Users/eding/Documents/projects/my-video-app:/video-app: ffmpeg-ruby-2.7 bash
docker run -it -v /Users/eding/Documents/projects/my-video-app:/video-app: ding-ffmpeg-ruby-2.7:latest bash

docker build -t ding-ffmpeg -f Dockerfile.ffmpeg .
docker build -t ding-ffmpeg-ruby-2.7 -f Dockerfile.new .