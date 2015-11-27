require 'webrtc-rails'

namespace :webrtc_rails do
  desc 'Start webrtc daemon'
  task start: :environment do
    start
  end

  desc 'Stop webrtc daemon'
  task stop: :environment do
    stop
  end

  desc 'Restart webrtc daemon'
  task restart: :environment do
    stop
    start
  end

  desc 'Check the status of webrtc daemon'
  task status: :environment do
    status
  end

  @pid_file = File.join(Rails.root, %w/tmp pids webrtc_rails.pid/)
  
  def start
    if File.exists?(@pid_file)
      pid = File.read(@pid_file)
      begin
        if Process.kill(0, pid.to_i)
          puts 'webrtc daemon alrerady exists'
          return
        end
      rescue Errno::ESRCH
      end
    end
    puts 'webrtc daemon started'
    Process.daemon(true, true)

    output_dir = WebrtcRails.configuration.output_dir
    stdout_file = File.join(output_dir, 'stdout')
    stderr_file = File.join(output_dir, 'stderr')

    FileUtils.mkdir_p(output_dir)
    $stdout.reopen(stdout_file)
    $stderr.reopen(stderr_file)
    
    File.write(@pid_file, Process.pid.to_s)
    daemon = WebrtcRails::Daemon.new
    daemon.start
  end

  def stop
    unless File.exists?(@pid_file)
      puts 'webrtc daemon does not exist'
      return
    end

    pid = File.read(@pid_file)
    begin
      if Process.kill(:INT, pid.to_i)
        puts 'webrtc daemon stoped'
        File.delete(@pid_file)
      end
    rescue Errno::ESRCH
      puts 'webrtc daemon does not exist'
    end
  end

  def status
    unless File.exists?(@pid_file)
      puts 'webrtc daemon is not running'
      return
    end

    pid = File.read(@pid_file)
    begin
      if Process.kill(0, pid.to_i)
        puts 'webrtc daemon is running'
      end
    rescue Errno::ESRCH
      puts 'webrtc daemon is not running'
    end
  end
end
