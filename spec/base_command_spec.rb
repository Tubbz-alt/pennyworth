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

require "spec_helper.rb"

describe Pennyworth::BaseCommand do
  it "processes the base image parameter" do
    c = Pennyworth::BaseCommand.new("/foo")

    all_base_images = ["aaa", "bbb", "ccc"]

    expect(c.process_base_image_parameter(all_base_images, "bbb")).to eq ["bbb"]
    expect { c.process_base_image_parameter(all_base_images, "xxx") }.to raise_error
    expect(c.process_base_image_parameter(all_base_images, nil)).to eq ["aaa", "bbb", "ccc"]
  end
end
