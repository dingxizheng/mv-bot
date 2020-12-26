# frozen_string_literal: true
require "selenium-webdriver"
require "watir"
require "faker"

class GoogleAccount
  class << self
    def create
      first_name = Faker::Name.first_name
      last_name = Faker::Name.last_name
      username = "#{Faker::Name.initials}.#{first_name}.#{last_name}in2020".downcase
      password = "#{first_name}@gmail1"
      birthdate = Faker::Date.birthday(min_age: 18, max_age: 65)

      LOG.info "CREATING ACCOUNT: first_name = #{first_name}, last_name = #{last_name}, username = #{username}, pass = #{password}"

      browser.goto("https://accounts.google.com")
      browser.element(xpath: "//div[@role='button']/*/*[contains(text(), 'Create account')]/../..").click
      sleep 0.5
      browser.element(xpath: "//span[@aria-label='For myself']").click
      sleep 0.5
      browser.element(xpath: "//input[@id='firstName']").send_keys(first_name)
      sleep 0.5
      browser.element(xpath: "//input[@id='lastName']").send_keys(last_name)
      sleep 0.5
      browser.element(xpath: "//input[@id='username']").send_keys(username)
      sleep 0.5
      browser.element(xpath: "//input[@name='Passwd']").send_keys(password)
      sleep 0.5
      browser.element(xpath: "//input[@name='ConfirmPasswd']").send_keys(password)
      sleep 0.5
      browser.element(xpath: "//button/span[contains(text(), 'Next')]/..").click
      sleep 10
      # browser.element(xpath: "//input[@id='phoneNumberId']").send_keys("2046743769")
      browser.element(xpath: "//button/span[contains(text(), 'Next')]/..").click

      browser.element(xpath: "//select[@id='month']").click
      browser.element(xpath: "//select[@id='month']/option[contains(text(), 'May')]").click

      browser.element(xpath: "//input[@id='day']").send_keys("#{birthdate.day}")
      browser.element(xpath: "//input[@id='year']").send_keys("#{birthdate.year}")

      browser.element(xpath: "//select[@id='gender']").click
      browser.element(xpath: "//select[@id='gender']/option[contains(text(), 'Male')]").click

      browser.element(xpath: "//button/span[contains(text(), 'Next')]/..").click

      browser.element(xpath: "//div[@id='termsofserviceNext']").click
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