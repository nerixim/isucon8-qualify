root = Dir.getwd.to_s

bind 'tcp://0.0.0.0:8000'
pidfile "#{root}/tmp/puma/pid"
state_path "#{root}/tmp/puma/state"
rackup "#{root}/config.ru"
threads 4, 8
activate_control_app
