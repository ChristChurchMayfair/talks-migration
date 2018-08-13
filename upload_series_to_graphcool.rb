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

serieses = JSON.parse(File.read("uploaded_series.json"),:symbolize_names => true)

client = GraphqlClient.new(config[:graphQLEndpoint],nil)

serieses = serieses.map do |series|
  pp series
  
  query_result = client.execute(
    query: %{
      query {
        Series(name: "#{series[:name]}") {
          id, name
        }
      }
    }
  )

  if query_result["data"] && query_result["data"]["Series"]
    puts "#{series} already exists"
    series[:graphcool_id] = query_result["data"]["Series"]["id"]
  else
    puts "Creating #{series}"
    creation_result = client.execute(
      query: %{
        mutation {
          createSeries(name: "#{series[:name]}", subtitle: "#{series[:subtitle]}", image3x2Url: "#{series[:aws_image_url]}") {
            id, name
          }
        }
      }
    )
    pp creation_result
    series[:graphcool_id] = creation_result["data"]["createSeries"]["id"]
  end
  series 
end

File.write("graphcool_series.json",JSON.pretty_generate(serieses))
