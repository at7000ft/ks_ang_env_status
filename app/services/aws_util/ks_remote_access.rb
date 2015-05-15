#
# Title: KsRemoteAccess
# Description: 
#
# Author: rholl00 
# Date: 3/18/15
#
# gem install aws-sdk -v 1.42.0
# gem install net-ssh
require 'net/ssh'

class KsRemoteAccess

  def initialize(host, user = 'ubuntu')
    @host = host
    @user = user
    #Load absolute path to key file (works with different project install locations)
    @sshKeyPath = File.expand_path("../../../keys/devKey.pem", File.dirname(__FILE__))
    #puts "keyPath - #{@sshKeyPath}"
  end

  #
  # Return an array of version file and contents
  # If a fingerprint error occurs clear .ssh/known_hosts
  #
  def getRemoteVersionFileNames(path)
    begin
      session = Net::SSH.start(@host, @user, :keys => [@sshKeyPath])
      output = session.exec!("ls /var/tmp")
      #puts "Read remote output #{output}"
      files = output.split("\n")

      versionFiles = []
      files.each do |file|
        if file.include? '-version.txt'
          versionFiles << file
        end
      end
      #puts "Version files - #{versionFiles}"
      versions = []
      versionFiles.each do |vfile|
        command = "cat /var/tmp/#{vfile}"
        output = session.exec!(command)
        #puts "Version #{vfile}-#{output}"
        versions << vfile + ': ' + output.delete!("\n")
      end
      session.close
    rescue Exception => e
      puts "\ngetRemoteVersionFileNames: Processing error occured - #{e.message}  (if fingerprint error need to remove .ssh/knownhosts)\n"
      cleanUpKnowhosts()
    end
    versions
  end

  def cleanUpKnowhosts()
    begin
      #Remove local known_hosts for next time
      system('rm ' + ENV['HOME'] + '/.ssh/known_hosts')
      versions = ['Not found']
    rescue Exception => e
      puts "Error removing .ssh/known_hosts - #{e.message}"
      return
    end
    puts "Removed .ssh/known_hosts file"
  end

end

if __FILE__==$0
  addr = '10.182.203.39'
  rem = KsRemoteAccess.new(addr)
  puts "Versions for addr #{addr} - #{rem.getRemoteVersionFileNames('/var/tmp')}"
end