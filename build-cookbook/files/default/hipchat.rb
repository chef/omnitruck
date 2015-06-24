require 'hipchat'

module BuildCookbook
  class HipChatHandler < Chef::Handler

    def initialize(api_token, room_name, notify_users=false)
      @api_token = api_token
      @room_name = room_name
      @notify_users = notify_users
    end

    def report
      msg = "<strong>[#{node['delivery']['change']['project']}] (#{node['delivery']['change']['stage']}:#{node['delivery']['change']['phase']})</strong> Change Failed: #{make_link(change_url)}"
      Chef::Log.error msg
      client = HipChat::Client.new(@api_token)
      client[@room_name].send('Delivery', msg, :color => 'red', :notify => @notify_users)
    end
  end
end
