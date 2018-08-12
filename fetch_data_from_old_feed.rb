require 'nokogiri'
require 'open-uri'
require 'aws-sdk-s3'
require 'uri'


require 'pp'

WP_RSS_FEED="http://www.christchurchmayfair.org/our-talks/podcast/"

mapping = {
  title: "title/text()",
  speaker: "ccm:author/text()",
  series_name: "ccm:seriesname/text()",
  bible_passage: "ccm:biblepassage/text()",
  event: "ccm:event/text()",
  series_subtitle: "ccm:seriessubtitle/text()",
  image_url: "itunes:image/@href",
  media_url: "media:content/@url",
  media_file_size: "media:content/@fileSize",
  media_mime_type: "media:content/@type",
  media_medium: "media:content/@medium",
  media_duration_in_seconds: "media:content/@duration" 
}

# Fetch and parse HTML document
doc = Nokogiri::XML(open(WP_RSS_FEED))

items = doc.xpath('//item' )

sermons = items.map do |item|
  mapping.map {|key,xpath| [key, item.xpath(xpath).text]}.to_h
end

# Convert some keys to ints
sermons = sermons.map do |sermon|
  keys_to_int = [:media_duration_in_seconds, :media_file_size]
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

event_name_fixes = {
 "6PM Service" => "Evening Service",
 "PM Service" => "Evening Service",
 "The Bible Talks" => "Evening Service",
 "House Party 2015" => "Houseparty 2015",
 "6PM Sermon" => "Evening Service",
 "AM Service" => "Morning Service",
 "AM service" => "Morning Service",
 "Evening service" => "Evening Service",
 "Morning service" => "Morning Service",
 "The Bible talks" => "Evening Service",
}
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

File.write("fetched_sermons.json",JSON.pretty_generate(sermons))
File.write("fetched_series.json",JSON.pretty_generate(series))
File.write("fetched_events.json",JSON.pretty_generate(events))
File.write("fetched_speakers.json",JSON.pretty_generate(speakers))
  







