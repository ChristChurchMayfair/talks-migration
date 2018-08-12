require 'nokogiri'
require 'open-uri'
require 'aws-sdk-s3'
require 'uri'
require 'pp'
require 'json'

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
    sermon[key] = sermon[key].to_i
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
  event_name_fixes.each do |old,new|
    if sermon[:event] == old
       sermon[:event] = new
    end
  end
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
  { series_name: sermon[:series_name],
    series_subtitle: sermon[:series_subtitle],
    series_image: sermon[:image_url]
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
  







