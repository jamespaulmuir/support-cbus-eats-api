require 'airrecord'
require 'aws-sdk-s3'

AIRTABLE_API_KEY = ENV["AIRTABLE_API_KEY"]
BASE = "appwweCl8Lnfbf9Vs"

utf8 = Encoding.find("UTF-8")

districts_by_id = Airrecord.table(AIRTABLE_API_KEY, BASE, "City Districts").all.inject({}) do |result, record|
  result[record.id] = record.fields["Name"]
  result
end

restaurants = Airrecord.table(AIRTABLE_API_KEY, BASE, "Restaurants").all.map(&:fields).map do |fields|
  # clean up keys
  fields.transform_keys! do |key|
    key.encode(utf8).downcase.gsub(/[^\s\w]+/, "").strip.gsub(/\s+/, "_").to_sym
  end

  # districts are in a separate table, map district ID to get district name
  fields[:district] = fields[:district]&.map {|district_id| districts_by_id[district_id] }&.first

  # removing, front-end client probably doesn't need this cache value
  fields.delete(:cache)
  fields
end


restaurants_json = restaurants.to_json

s3 = Aws::S3::Client.new
stored_object = s3.get_object(bucket: 'db-supportcolumbuseats-com', key: 'restaurants.json')

if stored_object.body.read != restaurants_json
  print "Updating json in s3"
  s3.put_object(
    bucket: 'db-supportcolumbuseats-com',
    key: 'restaurants.json',
    body: restaurants_json
  )
else
  print "JSON already up to date."
end
