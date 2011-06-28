require 'active_support/core_ext'
require 'icalendar'

module Timetable
  class Cache
    COLLECTION = "cache"

    # Return whether a particular course ID is cached in the database.
    # A course ID is considered cached if there is a corresponding record
    # in the database and that record is no more than 30 minutes old.
    #
    # @param [Integer] course_id The course ID.
    # @return [TrueClass, FalseClass] A boolean value indicating whether
    #   the given course ID is already cached in the database.
    def self.has?(course_id)
      return false if ENV['RACK_ENV'] == 'test'

      Database.execute(COLLECTION) do |db|
        db.exists?(
          "course_id" => course_id,
          "created_on" => { "$gte" => 30.minutes.ago }
        )
      end
    end

    # Retrieve the cached events for a given course ID, no matter how long
    # ago the record was saved to cache.
    #
    # @param [Integer] course_id The course ID.
    # @return [Array] An array of {Icalendar::Event} objects.
    def self.get(course_id)
      events = Database.execute(COLLECTION) do |db|
        db.find("course_id" => course_id)["events"]
      end
      events.map { |e| Icalendar::Event.unserialize(e) }
    end

    # Saves the events list for a given course_id in serialized form,
    # as well as when the cached record was created
    def self.save(course_id, events)
      return if ENV['RACK_ENV'] == 'test'

      doc = {
        "course_id" => course_id,
        "created_on" => Time.now,
        "events" => events.map(&:serialize)
      }

      Database.execute(COLLECTION) do |db|
        old = db.find("course_id" => course_id)
        if old
          # Update the pre-existing document
          db.update(old, doc)
        else
          # Insert a new one otherwise
          db.insert(doc)
        end
      end
    end
  end
end

module Icalendar
  class Event
    # Returns a hash with the essential attributes of the event,
    # ready to be inserted into a MongoDB collection
    def serialize
      {
        "uid"         =>  uid,
        "start"       =>  start.to_time,
        "end"         =>  self.end.to_time,
        "summary"     =>  summary,
        "description" =>  description,
        "location"    =>  location
      }
    end

    def self.unserialize(hash)
      # Mongo doesn't support {DateTime} objects, so start and end times
      # are serialized as {Time} objects, here we simply convert them back
      hash["start"] = hash["start"].to_datetime
      hash["end"] = hash["end"].to_datetime

      # Iterate over every (key, value) pair of the serialized hash
      # and call the corresponding key= method on our newly-created
      # {Event} object, with value as its argument. This simply populates
      # the attributes of the event with the serialized data.
      event = Event.new
      hash.each do |key, value|
        event.send("#{key}=".to_sym, value)
      end

      event
    end
  end
end