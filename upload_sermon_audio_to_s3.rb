require 'nokogiri'
require 'open-uri'
require 'aws-sdk-s3'
require 'uri'
require 'json'
require 'pp'

config = JSON.parse(File.read("config.json"),:symbolize_names => true)

sermons = JSON.parse(File.read(ARGV[0]),:symbolize_names => true)

creds = JSON.load(File.read('awssecrets.json'))
Aws.config[:credentials] = Aws::Credentials.new(creds['AccessKeyId'], creds['SecretAccessKey'])

s3 = Aws::S3::Resource.new(region:config[:targetRegion])
media_bucket = s3.bucket(config[:targetBucket])

sermons = sermons.map do |sermon|
  if sermon[:media_url] != ""
    uri = URI.parse(sermon[:media_url])
    file_name = File.basename(uri.path)
    file_location = File.join("sermon-cache",file_name)
  
    if ! File.exist? (file_location)
      puts "Downloading #{sermon[:media_url]}"
      `curl -o #{file_location} #{sermon[:media_url]}`
    else
      puts "Already got #{file_name} locally - not downloading"
    end
  
    sermon[:media_file_size] = File.size?(file_location)
    sermon[:media_file_md5] = `md5 -q #{file_location}`

    new_media_object = media_bucket.object(File.join(config[:talksBucketFolder],file_name))
  
    if ! new_media_object.exists?
      puts "Uploading #{file_name} to #{media_bucket.name}"
      new_media_object.upload_file(file_location)
    elsif ! remote_size = new_media_object.content_length 
      puts "Size mismatch - reuploading"
      puts "Local: #{sermon[:media_file_size]}"
      puts "Remote: #{remote_size}"
      new_media_object.upload_file(file_location)
    else
      puts "Already there with a matching md5 or size"
    end
       
    sermon[:aws_url] = new_media_object.public_url
  end
  sermon
end

File.write("uploaded_sermons.json",JSON.pretty_generate(sermons))
