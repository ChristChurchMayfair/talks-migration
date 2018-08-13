require 'open-uri'
require 'json'
require 'pp'
require 'httparty'

class GraphqlClient
  def initialize(url, token)
    @url = url
    @token = token
  end
 
  def execute(query:, variables: nil)
    HTTParty.post(
      @url,
      headers: { 
        'Content-Type'  => 'application/json', 
        'Authorization' => "Bearer #{@token}" 
      },
      body: { 
        query: query, 
        variables: variables 
      }.to_json
    )
  end
end

config = JSON.parse(File.read("config.json"),:symbolize_names => true)

events = JSON.parse(File.read("fetched_events.json"),:symbolize_names => true)

client = GraphqlClient.new(config[:graphQLEndpoint],nil)

events = events.map do |event|
  pp event
  event_name = event
  event = {}
  event[:name] = event_name

  query_result = client.execute(
    query: %{
      query {
        Event(name: "#{event[:name]}") {
          id, name
        }
      }
    }
  )

  if query_result["data"] && query_result["data"]["Event"]
    puts "#{event} already exists"
    event[:graphcool_id] = query_result["data"]["Event"]["id"]
  else
    puts "Creating #{event}"
    creation_result = client.execute(
      query: %{
        mutation {
          createEvent(name: "#{event[:name]}") {
            id, name
          }
        }
      }
    )
    event[:graphcool_id] = creation_result["data"]["createEvent"]["id"]
  end
  event 
end

File.write("graphcool_events.json",JSON.pretty_generate(events))
