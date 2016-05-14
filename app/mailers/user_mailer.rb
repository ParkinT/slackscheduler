class UserMailer < ApplicationMailer
  default from: 'SlackScheduler@Websembly.com'

  def welcome_email(user)
    @user = user
    @url = 'http://slackscheduler.herokuapp.com/'
    mail(to: @user.email, subject: 'Welcome to Slack Scheduler')
  end

  def notification_email(user, ical)
    @user = user
    events = ical.instance_variable_get(:@events)
    @summary = events.first.instance_variable_get(:@summary)
    #mail.attachments['slackminder.ics'] = { mime_type: 'application/ics', content: ical.to_ical }
    mail.attachments['slackschedule.ics'] = { mime_type: 'text/calendar', content: ical.to_ical }
    mail(to: @user.email, subject: "Slack Scheduler for #{@summary}")
  end
end

