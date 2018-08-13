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

speakers = JSON.parse(File.read("fetched_speakers.json"),:symbolize_names => true)

client = GraphqlClient.new(config[:graphQLEndpoint],nil)

speakers = speakers.map do |speaker|
  speaker_name = speaker
  speaker = {}
  speaker[:name] = speaker_name

  query_result = client.execute(
    query: %{
      query {
        Speaker(name: "#{speaker[:name]}") {
          id, name
        }
      }
    }
  )

  if query_result["data"] && query_result["data"]["Speaker"]
    puts "#{speaker} already exists"
    speaker[:graphcool_id] = query_result["data"]["Speaker"]["id"]
  else
    puts "Creating #{speaker}"
    creation_result = client.execute(
      query: %{
        mutation {
          createSpeaker(name: "#{speaker[:name]}") {
            id, name
          }
        }
      }
    )
    speaker[:graphcool_id] = creation_result["data"]["createSpeaker"]["id"]
  end
  speaker 
end

File.write("graphcool_speakers.json",JSON.pretty_generate(speakers))
