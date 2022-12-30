#!/usr/bin/env ruby
require 'net/http'
require 'json'


$keycloak_basepath = "http://127.0.0.1:3000"
$batch_size = 200

class Array
    def sum
        inject(0.0) { |result, el| result + el }
    end
  
    def mean 
        sum / size
    end
end

def percentile(values, percentile)
    values_sorted = values.sort
    k = ( percentile * ( values_sorted.length - 1 ) + 1 ).floor - 1
    f = ( percentile * ( values_sorted.length - 1 ) + 1 ).modulo(1)
    
    return values_sorted[k] + (f * (values_sorted[k+1] - values_sorted[k]))
end
  
def post_form(url, payload)
    uri = URI(url)
  
    http = Net::HTTP.new(uri.host, uri.port)
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER
  
    request = Net::HTTP::Post.new(uri)
    request.set_form(payload)
  
    http.request(request)
end

################################################################################
# Create tokens
################################################################################

$latency = []

def create_tokens_for_users(users)

    threads = []

    users.each do |user|

        threads << Thread.new do
            
            starting = Time.now

            # User auth
            token_response = post_form(
                "#{$keycloak_basepath}/realms/master/protocol/openid-connect/token",
                {
                    grant_type: 'password',
                    client_id: 'admin-cli',
                    username: user[:username],
                    password: 'password',
                    scope: 'openid profile email phone',
                }
            )
            
            ending = Time.now
            elapsed = ending - starting

            $latency.push(elapsed)
            puts "#{user[:username]} | token_response = #{token_response.code} | elapsed = #{elapsed}"

        end
    end

    threads.map(&:join)
end


# NOTE: Run until it's forced to stop
while true do

    puts "---- start ----"

    users = []

    for i in 1..$batch_size do
        users.push({
            "username": "test_user_#{rand(1..10000)}",
            "enabled": true,
            "credentials": [ { "type": "password", "value": "password" } ]
        })
    end

    create_tokens_for_users(users)

    puts "avg = #{$latency.mean()}s | min = #{$latency.min()}s | max = #{$latency.max()}s"
    puts "95% = #{percentile($latency, 0.95)} | 99% = #{percentile($latency, 0.99)}"

    puts "---- end ----"

end
