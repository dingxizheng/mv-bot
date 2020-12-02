# frozen_string_literal: true

class VideoProcessor < BaseProcessor
  class << self
    def start
      start_processing do
        loop do
          find_job_to_process
        end
      end
    end

    def find_job_to_process
      job = MusicJob.where(
        running: false,
        mp3_downloaded: true,
        cover_downloaded: true,
        ass_subtitles_generated: true,
        video_cover_generated: false,
        error: nil
      ).asc(:created_at).find_one_and_update({ "$set": { "running": true }}, new: false)
      if job.present?
        job.reload
        process_job(job)
      else
        LOG.info "No music job found for VideoProcessor, retry in 10 seconds."
        sleep(10)
      end
    end

    def process_job(music_job)
      job = music_job
      song = music_job.song

      LOG.info "Start making music video for job: #{music_job.id}, song_id: #{music_job.song.musicid}, name: #{music_job.song.name}, artist: #{music_job.song.artist}"

      if !job.video_cover_generated
        LOG.info "Generating video cover image..."
        VideoMaker.make_cover_image(input: song.cover_file_path, output: song.video_cover_file_path, artist: song.artist, title: song.clean_name)
        job.update!(video_cover_generated: true)
      end

      if !job.video_generated
        LOG.info "Generating video..."
        VideoMaker.make_video_with_subtitles(audio: song.audio_file_path, cover: song.video_cover_file_path, ass: song.ass_file_path, output: song.video_file_path)
        job.update!(video_generated: true)
      end

      LOG.info "Finished making music video for job: #{music_job.id}, song_id: #{music_job.song.musicid}, name: #{music_job.song.name}, artist: #{music_job.song.artist}"
    rescue => e
      job = music_job
      LOG.error "Failed to make music video, job_id: #{job.id}, error: #{e.message}"
      music_job.update(error: e.message)
    ensure
      music_job.update(last_run: Time.now, running: false)
    end
  end
end