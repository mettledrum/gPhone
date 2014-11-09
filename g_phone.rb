require 'sinatra'
require 'rubygems'
require 'twilio-ruby'
require 'httparty'
require 'active_support'
require 'active_support/core_ext'

get '/' do
  @@body = params[:Body]
  redirect to('/g_weather')
end

get '/g_weather' do
  # google geocoordinates API
  weather_search = @@body.gsub(" ", "+")
  google_api_response = HTTParty.get("https://maps.googleapis.com/maps/api/geocode/json?address=#{weather_search}")
  if google_api_response['status'] != "OK"
    @@error_msg = "Google request didn't work."
    redirect to('/not_right')
  end

  # forecast_io API
  city_lat = google_api_response["results"][0]["geometry"]["location"]["lat"]
  city_lng = google_api_response["results"][0]["geometry"]["location"]["lng"]
  forecast_io_response = HTTParty.get("https://api.forecast.io/forecast/#{ENV['FORECAST_IO_KEY']}/#{city_lat},#{city_lng}")
  if not forecast_io_response['error'].nil?
    @@error_msg = "Forecast.io request didn't work."
    redirect to('/not_right')
  end

  # all okay from APIs, get the weather info
  today_summary = forecast_io_response["daily"]["data"][0]["summary"]
  current_temp = forecast_io_response["currently"]["apparentTemperature"].round
  today_max = forecast_io_response["daily"]["data"][0]["apparentTemperatureMax"].round
  today_min = forecast_io_response["daily"]["data"][0]["apparentTemperatureMin"].round
  today_max_time = Time.at(forecast_io_response["daily"]["data"][0]["apparentTemperatureMaxTime"]).in_time_zone("America/Denver").strftime("%-l %p %Z")
  today_min_time = Time.at(forecast_io_response["daily"]["data"][0]["apparentTemperatureMinTime"]).in_time_zone("America/Denver").strftime("%-l %p %Z")
 
  # send weather text back
  message = "\n#{@@body}: #{today_summary}\nHigh of #{today_max}˚F at #{today_max_time}.\nLow of #{today_min}˚F at #{today_min_time}.\nNow: #{current_temp}˚F."
  twiml = Twilio::TwiML::Response.new do |r|
    r.Message message
  end
  twiml.text
end

# send error msg
get '/not_right' do
  twiml = Twilio::TwiML::Response.new do |r|
    r.Message @@error_msg
  end
  twiml.text
end
