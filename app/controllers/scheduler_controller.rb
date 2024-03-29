class SchedulerController < ApplicationController

  require 'icalendar/tzinfo'
  before_action :parse_input

  SLACK_SCHEDULER_USER_NAME = 'slack-scheduler'
  EPHEMERAL = "ephemeral"
  IN_CHANNEL = "in-channel"

  SETUP_CONFIGURATION_TEXT = ":dark_sunglasses: I need a little more information before I can do that for you\nSend this command, please\n`setup email: your.email@address.com timezone: X`\nWhere *X* is\n 1 for East US, 2 for Central US, 3 for Mountain US, 4 for Pacific US"
  SETUP_ERROR_TEXT = ":question: I did not quite understand your intent.\nTry again.\nRemember you need to follow *this* format `setup email: your.email@address.com timezone: X`\nWhere *X* is\n 1 for East US, 2 for Central US, 3 for Mountain US, 4 for Pacific US"

  TIMEZONES = ['', 'America/New_York', 'America/Chicago', 'America/Denver', 'America/Los_Angeless', 'America/Anchorage']

=begin
  response 'params'
      - token
      - team_id
      - team_domain
      - service_id
      - channel_id
      - channel_name
      - timestamp
      - user_id
      - user_name
      - text
      - trigger_word  | 'text' parameter includes the 'trigger_word'
=end

=begin
return json must include
      - username
      - response_type (in-channel or ephemeral)
      - text
=end
  def parse_input

    return if request.get?
    # parse input
    # If there is a quoted string that will be the 'schedule' text
    # If there is an email address that will be a target of an email notification
    #
    # It is important to properly parse time - we need to be aware of the current timezone (base it on the timestamp)
    # I would like to accept human-friendly times like named days of the week and "tomorrow", "next Tuesday", and the like
    case params[:trigger_word].downcase
    when 'setup'
      #@user_name = params[:user_name]
      user = find_or_create_user(params[:user_id])
      input = params[:text].downcase

      # better error handling
      email_input = input.match(/email:\W*mailto:([0-9a-zA-Z\._\+@]+)\W?/)
      timezone_input =  input.match(/timezone:\W(\d+)\W?/)

      if (email_input.blank? || timezone_input.blank?)
        render :json => test_object = { :username => SLACK_SCHEDULER_USER_NAME, :response_type => EPHEMERAL, :text => SETUP_ERROR_TEXT } and return
      end
      email = input.match(/email:\W*mailto:([0-9a-zA-Z\._\+@]+)\W?/)[1]
      timezone = TIMEZONES[input.match(/timezone:\W(\d+)\W?/)[1].to_i]

      user.update_attributes(name: params[:user_name], email: email, tz: timezone)
      UserMailer.welcome_email(user).deliver_now
      render :json => { :username => SLACK_SCHEDULER_USER_NAME, :response_type => EPHEMERAL, :text => "Configuration updated!\nA validation email has been sent to #{email}" } and return
    when 'schedule', 'sched', 'set'
      @user_name = params[:user_name]
      @user = find_or_create_user(params[:user_id])  #locate or add in database
      if @user.need_configuration?
        render :json => test_object = { :username => SLACK_SCHEDULER_USER_NAME, :response_type => EPHEMERAL, :text => SETUP_CONFIGURATION_TEXT } and return
      end

      input_string = params[:text]

      @attendees = parse_mentions(input_string)
      @mentions.each do |m|  #remove from the input string
        input_string.gsub("@#{m}", '')
      end

      date = find_date(input_string)
      begin
        render :json => { :username => SLACK_SCHEDULER_USER_NAME, :response_type => EPHEMERAL, :text => "Cannot interpret the #{date[0]} of #{date[1]}.\nUse 'Appointment *on* May 10, 2021'" } and return
      end if date.include? -1

      time = find_times(input_string)
      begin
        render :json => { :username => SLACK_SCHEDULER_USER_NAME, :response_type => EPHEMERAL, :text => "Cannot interpret '#{time[0]}'.\nSyntax: '... at 1:30PM'" } and return
      end if time.include? -1

      # here we will parse and calculate the duration
      @event_duration = { hours: 1, minutes: 0, text: "" }
      @event_duration[:text] = case @event_duration[:hours]
                 when 0
                   "#{'%02d' % @event_duration[:minutes]} minutes"
                 else
                   if @event_duration[:minutes] == 0
                     numeralize(@event_duration[:hours])
                   else
                     "#{@event_duration[:hours]}:#{'%02d' % @event_duration[:minutes]}"
                   end
                 end
      desc = input_string.scan(/[“"|'|\[|{](.*)[”"|'|\]|}]/)   #message is surrounded in "" or '' or [] or {}
      @description = desc[0][0]
      day = Date.new(date[0].to_i, date[1].to_i, date[2].to_i).wday
      weekday = case day
                when 0
                  'Sunday'
                when 1
                  'Monday'
                when 2
                  'Tuesday'
                when 3
                  'Wednesday'
                when 4
                  'Thursday'
                when 5
                  'Friday'
                when 6
                  'Saturday'
                end
      @summary = "#{@description[0..30].gsub(/\s\w+\s*$/,'...')} #{weekday} #{date[1]}-#{date[2]}"
      @summary = "#{@summary}-#{date[0]}" unless date[0].to_i == Date.today.year
      @summary = "#{@summary} (#{@event_duration[:text]})"
      @timezone_id = @user.tz

      @event_start = DateTime.new date[0].to_i, date[1].to_i, date[2].to_i, time[0].to_i, time[1].to_i
      # default to one-hour event - until I can implement "for x hours (minutes)"
      @event_end = DateTime.new date[0].to_i, date[1].to_i, date[2].to_i, time[0].to_i + @event_duration[:hours], time[1].to_i + @event_duration[:minutes]
      @event = create_calendar_event
    else
      # nop
    end

  end

  def index
    if request.post?
      summary =  @event.instance_variable_get(:@events).first.instance_variable_get(:@summary)
      UserMailer.notification_email(@user, @event).deliver_now
      @attendees.each do |a|  #notify any invited
        user = Slacker.find_by_email(a)
        UserMailer.notification_email(user, @event).deliver_now if user
      end if @attendees

     render :json => { :username => 'slack-scheduler', :response_type => "ephemeral", :text => "#{@summary} scheduled.\n" }
    else
      render :html => File.open('app/views/layouts/index.html').read.html_safe
    end
  end

  def find_or_create_user(slack_id)
    slacker = Slacker.where(slackid: slack_id)
    if slacker.any?
      slacker.first
    else
      Slacker.create(slackid: slack_id, name: @user_name)
    end
  end

  def parse_mentions(data_string)
    @mentions = data_string.scan(/@([a-z0-9]+)/)
    return nil if @mentions.size < 1
    attendees = []
    @mentions.each do |name|
      slacker = Slacker.find_by_name(name)
      #email = slacker.email if slacker
      email = Slacker.find_by_name(name).try(:email)
      attendees.push email if email #if there is no email simply ignore it
      #attendees.push "mailto:#{email}" if email #if there is no email simply ignore it

    end
    attendees
  end

  # return an array of [year, month, day]
  # Acceptable format(s):
  #     May 03, 2017
  def find_date(input_string)
    found_month = input_string.downcase.scan(/.*[on|ON|On]\s+(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)/)
    return ["month", found_month[0][0], -1] unless found_month
    month = case found_month[0][0]
      when 'jan'
        1
      when 'feb'
        2
      when 'mar'
        3
      when 'apr'
        4
      when 'may'
        5
      when 'jun'
        6
      when 'jul'
        7
      when 'aug'
        8
      when 'sep'
        9
      when 'oct'
        10
      when 'nov'
        11
      when 'dec'
        12
      end

    date_parts = input_string.scan(/(\d{1,2})\s?(,\s?\d{4})?/)
    day = date_parts[0][0]
    yr = date_parts[0][1].tr(', ', '') if date_parts[0][1]
    year = yr ||= Date.today.year
    # if the date is in the past, then year must be incremented
    year = Date.today.year.to_i + 1 if (Date.today > Date.parse("#{month}-#{day}-#{year}"))

    [year.to_i, month.to_i, day.to_i]
  end

  def find_times(input_string)
    found_time = input_string.scan(/[at|AT|At]\s+(\d{1,2})[:|\.](\d{2})/)
    if found_time.any?
      hour = found_time[0][0]
      minutes = found_time[0][1]
    else
      hour = 8
      minutes = 0
    end
    am_pm = input_string.match(/\d{1,2}[:|\.]\d{2}\s+([amPM]{1,2})/)
    # assume 24-hour clock unless...
    hour = hour.to_i + 12 if am_pm && am_pm[1].slice(0).downcase == "p"
    if hour.to_i > 24 || hour.to_i < 1
      minutes = -1 #flag a problem by setting minutes to negative
      hour = "#{found_time[0][0]}:#{found_time[0][1]} #{am_pm[1]}"
    end
    [hour, minutes]
  end

  def create_calendar_event
    cal = Icalendar::Calendar.new

    tzid = @timezone_id
    tz = TZInfo::Timezone.get tzid
    timezone = tz.ical_timezone @event_start
    cal.add_timezone timezone

    mailto = "mailto:#{@user.email}"
    cal.event do |e|
      e.dtstart = Icalendar::Values::DateTime.new @event_start, 'tzid' => tzid
      e.dtend   = Icalendar::Values::DateTime.new @event_end, 'tzid' => tzid
      e.summary = @summary
      e.description = @description
      e.organizer = mailto
      e.organizer = Icalendar::Values::CalAddress.new(mailto, cn: @user_name)
      #e.attendee @attendees if @attendees   # an array of 'mailto'
    end
    cal
  end

  def numeralize(number)
    # there may be a more elegant way to do this, but I do not have ready access to it at the moment
    case number
    when 1
      "One Hour"
    when 2
      "Two Hours"
    when 3
      "Three Hours"
    when 4
      "Four Hours!"
    when 5
      "Five Hours!"
    when 6
      "Six Hours!?"
    when 7
      "Seven Hours!?"
    when 8
      "Eight Hours. REALLY?"
    when 9
      "*Nine Hours*"
    when 10
      "*Ten Grueling Hours*"
    when 11
      "Eleven Hours"
    when 12
      "Twelve Hours"
    when 24
      "All Day"
    end
  end

end
