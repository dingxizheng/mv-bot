# frozen_string_literal: true

class MusicDownloader < BaseProcessor
  class << self
    def start
      start_processing do
        loop do
          find_job_to_process
        end
      end
    end

    def find_job_to_process
      job = MusicJob.where(running: false, ass_subtitles_generated: false, error: nil).asc(:created_at).find_one_and_update({ "$set": { "running": true }}, new: true)
      if job.present?
        job.reload
        process_job(job)
      else
        LOG.info "No music job found for MusicDownloader, retry in 10 seconds."
        sleep(10)
      end
    end

    def process_job(music_job)
      song = music_job.song
      LOG.info "Start downloading assets for job: #{music_job.id}, song_id: #{music_job.song.musicid}, name: #{music_job.song.name}, artist: #{music_job.song.artist}"

      if song.provider == "migu" && song.contentid.nil?
        LOG.info "Getting mp3 url and content id..."
        song_info = MiguMusic.song_info(song.musicid)
        song.update!(contentid: song_info["contentId"])
      end

      if song.mp3_url.nil?
        LOG.info "Getting 320 bit rate mp3 url..."
        if song.provider == "migu"
          mp3_url = MiguMusic.song_url(song.contentid, bit_rate: 320)
        else
          mp3_url = KuwoMusic.song_url(song.musicid)
        end
        song.update!(mp3_url: mp3_url)
      end

      if song.lyrics_list.nil? || song.lyrics_list.empty?
        LOG.info "Getting lyrics..."
        if song.provider == "migu"
          lyrics = MiguMusic.song_lyrics(song.copyrightid)
        else
          lyrics = KuwoMusic.song_lyrics(song.musicid)
        end
        song.update!(lyrics_list: lyrics)
      end

      if song.provider == "migu" && song.pic_url.nil?
        LOG.info "Getting song cover picture url..."
        cover_url = MiguMusic.song_pic_url(song.musicid)
        song.update!(pic_url: cover_url)
      end

      if !music_job.mp3_downloaded
        LOG.info "Downloading mp3 file..."
        if song.provider == "migu"
          MiguMusic.download_file(song.mp3_url, output: song.audio_file_path)
        else
          KuwoMusic.download_file(song.mp3_url, output: song.audio_file_path)
        end
        music_job.update!(mp3_downloaded: true)
      end

      if !music_job.cover_downloaded
        LOG.info "Downloading cover picture file..."
        if song.provider == "migu"
          MiguMusic.download_file(song.pic_url, output: song.cover_file_path)
        else
          KuwoMusic.download_file(song.pic_url, output: song.cover_file_path)
        end
        music_job.update!(cover_downloaded: true)
      end

      if !music_job.ass_subtitles_generated
        LOG.info "Writing ass subtitles file..."
        BaseProvider.lyrics_to_ass_file(song.lyrics_list, path: song.ass_file_path)
        music_job.update!(ass_subtitles_generated: true)
      end

      LOG.info "Finished downloading assets for song_id: #{music_job.song.musicid}, name: #{music_job.song.name}, artist: #{music_job.song.artist}"
    rescue => e
      job = music_job
      LOG.error "Failed to process  music job: #{job.id}, error: #{e.message}"
      music_job.update(error: e.message)
    ensure
      music_job.update(last_run: Time.now, running: false)
    end
  end
end