#!/usr/bin/env ruby
require 'net/http'
require 'json'


$keycloak_basepath = "http://127.0.0.1:3000"
$batch_size = 200

def post_form(url, payload)
    uri = URI(url)
  
    http = Net::HTTP.new(uri.host, uri.port)
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER
  
    request = Net::HTTP::Post.new(uri)
    request.set_form(payload)
  
    http.request(request)
end

def admin_login()

    admin_token_response = post_form(
        "#{$keycloak_basepath}/realms/master/protocol/openid-connect/token",
        {
          grant_type: 'password',
          client_id: 'admin-cli',
          username: 'admin',
          password: 'admin',
        }
    )
      
    puts "admin_token_response = #{admin_token_response.code}"

    return JSON.parse(admin_token_response.body)['access_token']
end

def post_json(url, payload, admin_token)
    uri = URI(url)
  
    http = Net::HTTP.new(uri.host, uri.port)
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER
  
    headers = {
        'Content-Type': 'application/json',
        'Authorization': "Bearer #{admin_token}"
    }
  
    request = Net::HTTP::Post.new(uri, headers)
    request.body = payload.to_json
  
    http.request(request)
end

################################################################################
# Create users
################################################################################

def create_users(users, realm, admin_token)

    threads = []

    users.each do |user|

        threads << Thread.new do
            
            starting = Time.now

            # Create user
            create_user_response = post_json("#{$keycloak_basepath}/admin/realms/#{realm}/users", user, admin_token)

            ending = Time.now
            elapsed = ending - starting

            puts "#{user[:username]} | create_user_response = #{create_user_response.code} | elapsed = #{elapsed}"

        end
    end

    threads.map(&:join)
end

full_start = Time.now

for i_batch in 0...50 do

    puts "---- batch start ----"

    admin_token = admin_login()

    r_start = i_batch * $batch_size + 1
    r_end = (i_batch + 1) * $batch_size

    users = (r_start..r_end).map { |i|
        {
            "username": "test_user_#{i}",
            "enabled": true,
            "credentials": [ { "type": "password", "value": "password" } ]
        }
    }

    create_users(users, "master", admin_token)

    puts "---- #{r_end} users created ----"

end

full_end = Time.now
total_elapsed = full_end - full_start

puts "---- completed in #{total_elapsed} sec ----"
