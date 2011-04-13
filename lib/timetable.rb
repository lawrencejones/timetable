require 'sinatra'
require File.join(File.dirname(__FILE__), 'calendar')

module Timetable
  get '/' do
    "This is the index page"
  end

  get '/:course/:yoe' do
    calendar = Calendar.new(params[:course], params[:yoe])
    calendar.to_ical
  end
end