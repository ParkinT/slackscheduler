# Slack Scheduler

### What is it

Yes.  Slack has a 'reminder' feature.  But that is insufficient for our needs. This is more of a Scheduling Capability from Slack.  Although we spend **all day** in Slack and it is our primary channel for communication, most meetings and other reminders come through the email client.
This application permits you to **generate** a reminder or a meeting
without interrupting your normal flow of work.  No need to switch away from Slack and into email or calendar.  Just setup a meeting - within Slack - and all registered participants will recieve a notification by email; a standard Internet Calendar meeting notice!

The format is simple.  Here are some examples that will make it clear.

```
schedule "Sprint Update Meeting" on June 10, 2016 at 2:11 pm

schedule [Follow up on product launch] on May 4

schedule "Product Discussion" on May 27 at 3:00 pm @sean @paul @alex

```
{ A few things to note about these examples:
  - The **message** that will included as the title and text of any notifications must be surrounded by matching quotes or square brackets (" or ' are acceptable)
  - Two important keywords to use are **AT** and **ON**.  These denote the Date and Time (respectively)
  - Although month (must be as a word; but can be as short as three letters; 'sep' for example) and date **must** be present, the year is optional.  This year will be assumed.
  - The time can be expressed in 12-hour or 24-hour format but **must** include hours AND minutes
  - The time __is__ optional.  If no time is given 8am will be assumed
  - The time is in YOUR LOCAL TIMEZONE (set as part of the configuration - see below) and will be adjusted for all participants
  - You can "mention" others (by their Slack handle) to be included, and invited to, but they must have setup their configuration in order to receive the invitation

Before you can utilize the functionality you will need to "setup" your details in the application.  No fear; this is also accomplished through Slack!

This is accomplished with a single message TO the Slack Scheduler:
`setup email: your_email@domain.com timezone: 3 `
The __timezone__ parameter is (in this initial release) a very simple
choice from among:
  - 1 for East US
  - 2 for Central US
  - 3 for Mountian US
  - 4 for Pacific US
  - 5 for Alaska

{You can get a hint about these with `schedule setup` }
Note: If you are a member of several Slack groups you will need to perform this configuration/setup for each. In this way your "work" Slack will send notifications to your work email and others **could be** connected to different email accounts.

### Slack Setup

In the Slack __Apps & Integrations__ set it up as an "Outgoing Webhook" in  "Custom Integration".
The 'trigger_words' should contain `schedule, setup` and the URL should b `https://slackscheduler.herokuapp.com/schedule`.  I recommend the 'Descriptive Label' be `Slack Scheduler` and the 'Customize Name' should be `slack-scheduler`.  I really believe the `:calendar:` emoji is most appropriate to use.

---


I encourage suggestions and comments.  This has been developed entirely
in my spare time as a 'labor of love' so I ask for patience when
requesting features or changes in functionality.

&copy; 2016 [Thom Parkin](mailto:parkint+github@gmail.com)

