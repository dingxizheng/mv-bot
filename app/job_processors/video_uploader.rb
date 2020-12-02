# frozen_string_literal: true

class VideoUploader < BaseProcessor
  class << self
    def start
      start_processing do
        loop do
          if @cool_down_time
            LOG.info "Sleep uploader for #{@cool_down_time} seconds"
            sleep @cool_down_time
            @cool_down_time = nil
          end
          find_job_to_process
        end
      end
    end

    def find_job_to_process
      job = MusicJob.where(
        running: false,
        video_generated: true,
        video_uploaded: false,
        error: nil
      ).asc(:created_at).find_one_and_update({ "$set": { "running": true }}, new: false)
      if job.present?
        job.reload
        process_job(job)
      else
        LOG.info "No music job found for VideoUploader, retry in 10 seconds."
        sleep(10)
      end
    end

    def process_job(music_job)
      job = music_job
      song = music_job.song

      LOG.info "Start uploading music video for job: #{music_job.id}, song_id: #{music_job.song.musicid}, name: #{music_job.song.name}, artist: #{music_job.song.artist}"

      tags = ["华语", "经典", "歌词", "高清"]
      tags << song.artist

      data = {
        title: "#{song.artist} - #{song.name} (动态歌词/最高音质)",
        description: song.song_description,
        video: File.join(ENV["UPLOADER_FILE_FOLDER"], song.video_file_path(relative: true)),
        kids: false,
        tags: tags.join(","),
        publish_type: "PUBLIC"
      }

      if !job.video_uploaded
        LOG.info "Uploading video..."
        Youtube.upload_video(**data)
        job.update!(video_uploaded: true)
      end

      LOG.info "Finished uploading video for job: #{music_job.id}, song_id: #{music_job.song.musicid}, name: #{music_job.song.name}, artist: #{music_job.song.artist}"
    rescue Youtube::DailyUploadLimitError => e
      @cool_down_time = 3600
      LOG.error "Failed to upload video, job_id: #{job.id}, error: #{e.message}, cooling down for 3600 seconds."
    rescue => e
      job = music_job
      LOG.error "Failed to upload video, job_id: #{job.id}, error: #{e.message}"
      music_job.update(error: e.message)
    ensure
      music_job.update(last_run: Time.now, running: false)
    end
  end
end