require './lib/json_by_url'

Event.destroy_all
Sport.destroy_all
Market.destroy_all
Outcome.destroy_all

def conv_epoch(epoch)
    Time.at(epoch.to_i / 1000).to_datetime #trim milliseconds from epoch time
end

system "clear"
puts "Fetching Current Bovada Info..."
resp = JSONByURL.new 'https://www.bovada.lv/services/sports/event/v2/events/A/description'


if resp.clean
    data = resp.json

    sports_import, events_import, markets_import, outcomes_import = [], [], [], []
    data.each do |league|
        
        link = league["path"][0]["link"]
        sport_attributes = link.split("/", 3)[1..]
        sport = Sport.find_or_create_by(sport_name: sport_attributes[0], sub_name: sport_attributes[1])
        
        puts "Building Models for #{link}"

        league["events"].each do |e|  
            bldr = {description: e["description"], link: e["link"], bovada_id: e["id"],
                        start_time: conv_epoch(e["startTime"]), sport_id: sport.id, event_type: e["type"],
                        last_modified: conv_epoch(e["lastModified"])}
            
            event = Event.new(bldr) #WOULD BE MODIFIED TO AVOID DUPLICATE EVENT DATA IN LOG-LIVE-DATA PHASE

            e["displayGroups"].each do |b|
                
                market_type = b["description"]

                b["markets"].each do |c| #BELOW WOULD BE MODIFIED TO AVOID DUPLICATE MARKET DATA IN FUTURE
                    market = event.markets.build(bovada_id: c["id"], market_type: market_type,
                         description: c["description"], period: c["period"]["description"], 
                         live: c["period"]["live"])
                    
                    
                    unless c["outcomes"].empty?  #sometimes no bet outcomes available, possibly when bet taken down temp.
                        c["outcomes"].each do |j|  #BELOW WOULD BE MODIFIED TO LOG LIVE BET DATA IN FUTURE OVER TIME
                            market.outcomes.build(american: j["price"]["american"], decimal: j["price"]["decimal"],
                                description: j["description"], market_id: market.id, bovada_id: j["id"],
                                bovada_status: j["status"], bovada_type: j["type"])
                        end
                    end
                end
                
            end
            
            events_import << event  #markets and outcomes built, headed for next Event
        end
    end
    system "clear"
    puts "Generating Models! Hold on to your butts."
    Event.import events_import, recursive: true



else
    puts "Error Retrieving: https://www.bovada.lv/services/sports/event/v2/events/A/description"
end