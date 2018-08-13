require 'nokogiri'
require 'open-uri'
require 'aws-sdk-s3'
require 'uri'
require 'pp'
require 'json'
require 'date'

config = JSON.parse(File.read("config.json"),:symbolize_names => true)

puts "Running with config:"
pp config

mapping = config[:rssXMLXPathMappings]

# Fetch and parse HTML document
doc = Nokogiri::XML(open(config[:sourceRSSFeed]))

items = doc.xpath('//item' )

sermons = items.map do |item| 
  mapping.map {|key,xpath| [key, item.xpath(xpath).text]}.to_h
end

keys_to_int = config[:keysToInteger]

# Convert some keys to ints
sermons = sermons.map do |sermon|
  keys_to_int.each do |key|
    sermon[key.to_sym] = sermon[key.to_sym].to_i
  end
  sermon
end

keys_to_date_time_iso8601 = config[:keysToTimeStamp]
# Convert some keys to 8601 timestamps
sermons = sermons.map do |sermon|
  keys_to_date_time_iso8601.each do |key|
    sermon[key.to_sym] = DateTime.parse(sermon[key.to_sym]).iso8601
  end
  sermon
end

#Tidy up double speakers, not very nice but since we only have one bad instance this will do.
sermons = sermons.map do |sermon|
  sermon[:speakers] = sermon[:speaker].split(" & ")
  sermon
end

event_name_fixes = config[:eventNameFixes]
# Fix event names
sermons = sermons.map do |sermon|
  sermon[:event] = event_name_fixes[sermon[:event].to_sym] if event_name_fixes[sermon[:event].to_sym]
  sermon
end

# Fix sermons with missing event...
sermons = sermons.map do |sermon|
  if sermon[:event] == ""
    if sermon[:media_url].include?('_AM_')
      sermon[:event] = "Morning Service"
    elsif sermon[:media_url].include?('_PM_')
      sermon[:event] = "Evening Service"
    end
  end
  sermon
end

speakers = sermons.flat_map {|sermon| sermon[:speakers]}.uniq

series = sermons.map do |sermon|
  { name: sermon[:series_name],
    subtitle: sermon[:series_subtitle],
    image: sermon[:image_url]
  }
end.uniq

events = sermons.map {|sermon| sermon[:event]}.uniq

puts "sermons:  #{sermons.count}"
puts "series:   #{series.count}"
puts "events:   #{events.count}"
puts "speakers: #{speakers.count}"

File.write("fetched_sermons.json",JSON.pretty_generate(sermons))
File.write("fetched_series.json",JSON.pretty_generate(series))
File.write("fetched_events.json",JSON.pretty_generate(events))
File.write("fetched_speakers.json",JSON.pretty_generate(speakers))
  







