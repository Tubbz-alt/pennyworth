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

module Pennyworth
  class ImageRunner < Runner
    DOMAIN_TEMPLATE = File.join(File.dirname(__FILE__) + "/../../files/image_test-template.xml")

    attr_accessor :name

    def initialize(image, username)
      @image = image
      @name = File.basename(image)
      @username = username

      @connection = ::Libvirt::open("qemu:///system")
    end

    def start
      cleanup

      ip = start_built_image
      @command_runner = RemoteCommandRunner.new(ip, @username)

      ip
    end

    def stop
      system = @connection.lookup_domain_by_name(@name)
      system.destroy
    end

    def cleanup_directory(_dir)
      # The machine will be reset anyway after the tests, so this is is a NOP
    end

    private

    def cleanup
      system = @connection.lookup_domain_by_name(@name)
      system.destroy
    rescue
    end

    # Creates a transient kvm domain from the predefined image_test-domain.xml
    # file and returns the ip address for further interaction.
    def start_built_image
      domain_config = File.read(DOMAIN_TEMPLATE)
      domain_config.gsub!("@@image@@", @image)
      domain_config.gsub!("@@name@@", @name)

      @connection.create_domain_xml(domain_config)
      system = @connection.lookup_domain_by_name(@name)

      domain_xml = REXML::Document.new(system.xml_desc)
      mac = domain_xml.elements["//domain/devices/interface/mac"].attributes["address"]
      ip_address = nil

      # Loop until the VM has got an IP address we can return
      300.times do
        ip_address = Cheetah.run(
          ["arp", "-n"],
          ["grep", mac],
          ["cut", "-d", " ", "-f", "1"],
          stdout: :capture
        ).chomp

        if ip_address.length > 0
          break
        end

        sleep 1
      end

      ip_address
    end
  end
end
