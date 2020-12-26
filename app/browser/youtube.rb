# frozen_string_literal: true

require "selenium-webdriver"
require "watir"

class Youtube
  class DailyUploadLimitError < StandardError; end
  YOUTUBE_COOKIES_PATH = "youtube.cookies"

  class << self
    def subscribe
    end

    def upload_video(title:, description:, video:, kids: false, tags:, publish_type:, category: "Music")
      LOG.info "Upload vdieo title: #{title}, description: #{description}"
      browser.goto("https://www.youtube.com/")
      LOG.info "Load cookies from #{YOUTUBE_COOKIES_PATH}"
      load_cookies(YOUTUBE_COOKIES_PATH)

      sleep 0.5
      browser.goto(ENV["YOUTUBE_STUDIO_VIDEOS_URL"])

      sleep 0.5
      # If gets redirected to login page
      if browser.url.include?("accounts.google.com/signin")
        LOG.info "On sign in page ..."
        youtube_login
        return upload_video
      end

      LOG.info "Click 'Create'"
      browser.element(xpath: "//ytcp-button/*[text()='Create']/..").click
      LOG.info "Click 'Upload videos'"
      browser.element(xpath: "//yt-formatted-string[text()='Upload videos']").click

      # set video file
      LOG.info "Select video file: '#{video}'"
      browser.element(xpath: "//input[@type='file' and @name='Filedata']").send_keys(video)

      begin
        browser.element(xpath: "//div[contains(text(), 'Daily upload limit reached')]").wait_until(timeout: 20, &:present?)
        raise Youtube::DailyUploadLimitError, "Daily upload limit reached"
      rescue Youtube::DailyUploadLimitError
        raise
      rescue
        # ingore...
      end

      # clear title
      LOG.info "Set video title: '#{title}'"
      sleep 1
      browser.element(xpath: "//div[@id='textbox' and @aria-label='Add a title that describes your video']").clear()
      # add title
      browser.element(xpath: "//div[@id='textbox' and @aria-label='Add a title that describes your video']").send_keys(title)
      # add description
      LOG.info "Set video description: '#{description[0..3000]}'"
      browser.element(xpath: "//div[@id='textbox' and @aria-label='Tell viewers about your video']").send_keys(description[0..3000])

      # not make for kids
      LOG.info "Set video MADE_FOR_KIDS: '#{kids}'"
      if kids
        browser.element(xpath: "//paper-radio-button[@name='MADE_FOR_KIDS']").click
      else
        browser.element(xpath: "//paper-radio-button[@name='NOT_MADE_FOR_KIDS']").click
      end

      # expand more options
      browser.element(xpath: "//ytcp-button/div[text() = 'More options']").click

      # add tags
      if tags
        LOG.info "Set video TAGS: '#{tags}'"
        browser.element(xpath: "//input[@id='text-input' and @aria-label='Tags']").send_keys(tags)
      end

      # set category
      if category
        LOG.info "Set video CATEGORY: '#{category}'"
        browser.element(xpath: "//ytcp-form-select[@id='category']").click
        browser.element(xpath: "//paper-item[@test-id='CREATOR_VIDEO_CATEGORY_MUSIC']").click
      end

      # next
      browser.element(xpath: "//ytcp-button/div[text() = 'Next']").click
      # next
      browser.element(xpath: "//ytcp-button/div[text() = 'Next']").click
      # publish type
      browser.element(xpath: "//paper-radio-button[@name='PUBLIC']").click

      LOG.info "Wait for video to be processed..."
      # wait until video is processed
      total_seconds = 0
      loop do
        if browser.element(xpath: "//ytcp-video-upload-progress/span[text() = 'Finished processing']").exists?
          break
        elsif total_seconds > 10 * 60
          raise "Could not finish video processing in 5 minutes, meta: "
        else
          total_seconds += 2
          sleep 2
        end
      end

      # done
      browser.element(xpath: "//ytcp-button[@id='done-button']").click
      browser.element(xpath: "//div/h1[contains(text(), 'Video published')]").when_present(60).text
      LOG.info "Video uploaded!"
    end

    def youtube_login
      browser.goto(ENV["YOUTUBE_STUDIO_VIDEOS_URL"])
      browser.element(xpath: "//yt-formatted-string[text()='Sign in']").click

      username = ENV["YOUTUBE_USER"]
      password = ENV["YOUTUBE_PASS"]

      browser.element(xpath: "//input[@type='email' and @name='identifier']").send_keys(username)
      browser.element(xpath: "//button/*[contains(text(), 'Next')]/..").click

      browser.element(xpath: "//input[@type='password' and @name='password']").send_keys(password)
      browser.element(xpath: "//button/*[contains(text(), 'Next')]/..").click

      browser.element(xpath: "//yt-formatted-string[text()='JJ Music']").text

      # Save youtube cookies
      sleep 2
      browser.cookies.save(YOUTUBE_COOKIES_PATH)
    end

    def browser
      @driver ||= create_driver
    end

    def load_cookies(file)
      browser.cookies.load(file)
    end

    def create_driver
      if ENV["REMOTE_SELENIUM"] == "true"
        Watir::Browser.new(:firefox, { timeout: 2000, url: ENV["REMOTE_SELENIUM_URL"], use_capabilities: { unexpected_alert_behaviour: "accept" } })
      else
        Watir::Browser.new(:firefox, { timeout: 2000,  use_capabilities: { unexpected_alert_behaviour: "ignore" } })
      end
    end
  end
end