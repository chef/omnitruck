
group 'omnitruck'

user 'omnitruck' do
  gid 'omnitruck'
  home '/srv/omnitruck'
  shell '/bin/false'
  supports manage_home: true
end
