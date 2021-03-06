# Copyright (c) 2013-2014 SUSE LLC
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of version 3 of the GNU General Public License as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.   See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, contact SUSE LLC.
#
# To contact SUSE about this file by physical or electronic mail,
# you may find current contact information at www.suse.com

require "tempfile"

module Pennyworth
  class SshKeysImporter
    def self.import(ip, username, password, identity_file = nil)
      tmp_file = Tempfile.new("pennyworth-ssh-key-importer")

      cmd = "ssh-copy-id"
      if identity_file
        cmd << " -i \"#{identity_file}\""
        cmd << " -o \"IdentityFile=#{identity_file}\""
      end
      cmd << " -o \"UserKnownHostsFile=/dev/null\""
      cmd << " -o \"StrictHostKeyChecking=no\""
      cmd << " #{username}@#{ip}"

      # This temporary bash script copies the SSH keys to the host using
      # ssh-copy-id.
      #
      # In order to drive this interactive command it is executed by expect.
      tmp_file.write(<<-EOF
        #!/usr/bin/expect -f

        spawn #{cmd}
        expect {
          -re ".*assword.*" {
            send "#{password}\\r"
            expect {
              -re ".*assword.*" {
                exit 1
              }
              -re ".*Number of key.*" {
                exit 0
              }
            }
          }
          -re ".*Number of key.*" {
            exit 0
          }
          "skipped" {
            exit 2
          }
          "authenticity" {
            send "yes\\r"
            exp_continue
          }
          "Connection refused" {
            exit 3
          }
        }
        exit 4
      EOF
      )
      tmp_file.close

      attempt = 1
      begin
        Cheetah.run("expect", tmp_file.path)
      rescue Cheetah::ExecutionFailed => e
        case e.status.exitstatus
          when 1
            raise WrongPasswordException, "Error: Could not upload SSH keys because" \
              " the password is wrong."
          when 2
            raise SshKeysAlreadyExistsException, "SSH keys were not uploaded because they" \
              " were already on the host."
          when 3
            # We give sshd 30 seconds to start up
            if attempt > 30
              raise SshConnectionFailed, "SSH connection failed."
            else
              attempt += 1
              sleep 1
              retry
            end
          when 4
            raise RuntimeError, "An unknown error occurred while trying to upload " \
              "the SSH keys."
          when 127
            raise CommandNotFoundError, "Error: Please install expect before running" \
              " pennyworth copy-ssh-keys."
          else
            raise e
        end
      end
    ensure
      tmp_file.unlink
    end
  end
end
