require 'open-uri'
require 'json'
require 'pp'
require 'httparty'
require_relative 'graphcoolqueries'





creds = JSON.parse(File.read('graphcoolcreds.json'))

config = JSON.parse(File.read("config.json"),:symbolize_names => true)

sermons = JSON.parse(File.read("uploaded_sermons.json"),:symbolize_names => true)

client = GraphqlClient.new(config[:graphQLEndpoint],creds['graphcooltoken'])

sermons = sermons.map do |sermon|
  pp sermon
  
  query_result = client.execute(
    query: %{
      query {
        Sermon(url: "#{sermon[:aws_url]}") {
          id, name
        }
      }
    }
  ) 
  
  pp query_result

  if query_result["data"] && query_result["data"]["Sermon"]
    puts "#{sermon} already exists"
    sermon[:graphcool_id] = query_result["data"]["Sermon"]["id"]
  else
    puts "Creating #{sermon}"
    creation_result = client.execute(
      query: %{
        mutation {
          createSermon(name: "#{sermon[:title]}",
                       preachedAt: "#{sermon[:preachedAt]}",
                       duration: #{sermon[:media_duration_in_seconds]},
                       passage: "#{sermon[:bible_passage]}",
                       url: "#{sermon[:aws_url]}") {
            id, name
          }
        }
      }
    )
    pp sermon
    pp creation_result
    sermon[:graphcool_id] = creation_result["data"]["createSermon"]["id"]
  end


  sermon[:speakers].each do |speaker_name|
    speakerLookupResult = client.execute(
      query: speaker(speaker_name,['id'])
    )
    
    if speakerLookupResult["data"] && speakerLookupResult["data"]["Speaker"]
      speaker_id = speakerLookupResult["data"]["Speaker"]["id"]
      #Create link to speaker
      addSpeaker_query_result = client.execute(
        query: %{
          mutation {
            addToSermonOnSpeaker(
              speakersSpeakerId: "#{speaker_id}"
              sermonsSermonId: "#{sermon[:graphcool_id]}"
            )
            {
              sermonsSermon {
                name
              }
              speakersSpeaker {
                name
              }
            }
          }
        }
      )
      end
    puts addSpeaker_query_result
  end


  #Create link to event
  eventLookupResult = client.execute(
  query: event(sermon[:event],['id'])
  )

  if eventLookupResult["data"] && eventLookupResult["data"]["Event"]
    event_id = eventLookupResult["data"]["Event"]["id"]
    #Create link to speaker
    #
    puts event_id

    addEvent_query_result = client.execute(
    query: %{
          mutation {
            addToSermonOnEvent(
              eventEventId: "#{event_id}"
              sermonsSermonId: "#{sermon[:graphcool_id]}"
            )
            {
              sermonsSermon {
                name
              }
              eventEvent {
                name
              }
            }
          }
        }
    )
    puts addEvent_query_result
  end

  seriesLookupResult = client.execute(
      query: series(sermon[:series_name],['id'])
  )

  if seriesLookupResult["data"] && seriesLookupResult["data"]["Series"]
    series_id = seriesLookupResult["data"]["Series"]["id"]
    #Create link to event

    puts series_id

    addSeries_query_result = client.execute(
        query: %{
          mutation {
            addToSermonOnSeries(
              seriesSeriesId: "#{series_id}"
              sermonsSermonId: "#{sermon[:graphcool_id]}"
            )
            {
              sermonsSermon {
                name
              }
              seriesSeries {
                name
              }
            }
          }
        }
    )
    puts addSeries_query_result
  end

  #Create link to series

  sermon 
end

File.write("graphcool_sermon.json",JSON.pretty_generate(sermons))
