class MeetingNotification < ActionMailer::Base
     def meeting_request_with_calendar
       mail(:to => "any_email@example.com", :subject => "iCalendar",
       :from => "any_email@example.com") do |format|
       format.ics {
          ical = Icalendar::Calendar.new
          e = Icalendar::Event.new
          e.start = DateTime.now.utc
          e.start.icalendar_tzid="UTC" # set timezone as "UTC"
          e.end = (DateTime.now + 1.day).utc
          e.end.icalendar_tzid="UTC"
          e.organizer "any_email@example.com"
          e.uid "MeetingRequest#{unique_value}"
          e.summary "Scrum Meeting"
          e.description <<-EOF
Venue: Office
Date: 16 August 2011
Time: 10 am
EOF
          ical.add_event(e)
          i cal.publish
          ical.to_ical
          render :text => ical, :layout => false
      }
      end
    end
end
