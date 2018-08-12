require 'nokogiri'
require 'open-uri'
require 'aws-sdk-s3'
require 'uri'
require 'json'
require 'pp'

serieses = JSON.parse(File.read(ARGV[0]),:symbolize_names => true)

creds = JSON.load(File.read('awssecrets.json'))
Aws.config[:credentials] = Aws::Credentials.new(creds['AccessKeyId'], creds['SecretAccessKey'])

s3 = Aws::S3::Resource.new(region:'eu-west-1')
media_bucket = s3.bucket('media.christchurchmayfair.org')

serieses = serieses.map do |series|
  pp series
  if series[:series_image] != ""
    uri = URI.parse(series[:series_image])
    file_name = File.basename(uri.path)
    file_location = File.join("image-cache",file_name)
  
    if ! File.exist? (file_location)
      puts "Downloading #{series[:series_image]}"
      `curl -o #{file_location} #{series[:series_image]}`
    else
      puts "Already got #{file_name} locally - not downloading"
    end
  
    series[:series_image_file_size] = File.size?(file_location)
    series[:series_image_md5] = `md5 -q #{file_location}`
    
    new_media_object = media_bucket.object("series-images/"+file_name)
  
    if ! new_media_object.exists?
      puts "Uploading #{file_name} to #{media_bucket.name}"
      new_media_object.upload_file(file_location)
    elsif ! remote_size = new_media_object.content_length 
      puts "Size mismatch - reuploading"
      puts "Local: #{series[:media_file_size]}"
      puts "Remote: #{remote_size}"
      new_media_object.upload_file(file_location)
    else
      puts "Already there with a matching md5 or size"
    end
       
    series[:aws_image_url] = new_media_object.public_url
  end
  series
end

File.write("uploaded_series.json",JSON.pretty_generate(serieses))
  







