
RSpec.describe "networks" do
  CF_NETWORK_NAMES = %w(
    cf
    cell
    router
  ).freeze

  let(:networks) { manifest_with_defaults.fetch("networks") }

  CF_NETWORK_NAMES.each do |net_name|
    describe "#{net_name} network" do
      let(:network) { networks.find { |n| n["name"] == net_name } }

      it "should have at least two subnets" do
        expect(network["subnets"].length).to be >= 2
      end

      it "should set the correct subnet ID" do
        network["subnets"].length.times do |i|
          subnet_fixture_key = "#{net_name}#{i + 1}_subnet_id"
          expect(network["subnets"][i]["cloud_properties"]["subnet"]).to eq(terraform_fixture(subnet_fixture_key))
        end
      end
    end
  end
end
