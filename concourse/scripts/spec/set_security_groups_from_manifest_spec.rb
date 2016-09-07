require_relative "../set_security_groups_from_manifest"

RSpec.describe SecurityGroupsSetter do
  let(:security_group_definitions) { [] }
  let(:default_running_security_groups) { [] }
  let(:default_staging_security_groups) { [] }
  let(:manifest) {
    {
    "properties" => {
      "cc" => {
        "security_group_definitions" => security_group_definitions,
        "default_running_security_groups" => default_running_security_groups,
        "default_staging_security_groups" => default_staging_security_groups,
      },
    },
  }}
  subject { SecurityGroupsSetter.new(manifest) }

  before :each do
    allow(subject).to receive(:`).with('cf security-groups') do
      system("exit 0") # setup $?
      ""
    end
  end

  describe "creating/updating security group definitions" do
    before :each do
      allow(subject).to receive(:system).with("cf", /^(create|update)-security-group$/, any_args) do
        system("exit 0")
      end
    end

    context "with no extant security groups" do
      before :each do
        allow(subject).to receive(:`).with('cf security-groups') do
          system("exit 0") # setup $?
          <<-EOT
Getting security groups as admin
OK

     Name                   Organization   Space
          EOT
        end
      end

      it "creates the security groups" do
        dns_rules = [{ "protocol" => "tcp", "destination" => "10.0.0.2", "port" => "udp" }]
        smtp_rules = [{ "protocol" => "tcp", "destination" => "10.0.0.4", "port" => 25 }]
        security_group_definitions << { "name" => "dns", "rules" => dns_rules }
        security_group_definitions << { "name" => "smtp", "rules" => smtp_rules }

        expect_cf_sg_create("dns", dns_rules)
        expect_cf_sg_create("smtp", smtp_rules)

        subject.apply!
      end
    end

    context "when some security groups exist" do
      before :each do
        allow(subject).to receive(:`).with('cf security-groups') do
          system("exit 0") # setup $?
          <<-EOT
Getting security groups as admin
OK

     Name                   Organization   Space
#0   public_networks
#1   dns
#2   rds_broker_instances
#3   graphite-nozzle        admin          admin
          EOT
        end

        @dns_rules = [{ "protocol" => "tcp", "destination" => "10.0.0.2", "port" => "udp" }]
        @smtp_rules = [{ "protocol" => "tcp", "destination" => "10.0.0.4", "port" => 25 }]
        security_group_definitions << { "name" => "dns", "rules" => @dns_rules }
        security_group_definitions << { "name" => "smtp", "rules" => @smtp_rules }
      end

      it "updates an existing group" do
        expect_cf_sg_update("dns", @dns_rules)
        subject.apply!
      end

      it "creates a group that doesn't already exist" do
        expect_cf_sg_create("smtp", @smtp_rules)
        subject.apply!
      end
    end
  end

  describe "binding default security groups" do
    it "binds the default running security groups" do
      default_running_security_groups << "foo" << "bar"
      expect_cf_bind_sg("running", "foo")
      expect_cf_bind_sg("running", "bar")

      subject.apply!
    end

    it "binds the default staging security groups" do
      default_staging_security_groups << "foo" << "bar"
      expect_cf_bind_sg("staging", "foo")
      expect_cf_bind_sg("staging", "bar")

      subject.apply!
    end
  end

  def expect_cf_sg_write(name, rules, action)
    expect(subject).to receive(:system).with("cf", action, name, anything) do |_, _, _, rules_file|
      actual_rules = JSON.parse(File.read(rules_file))
      expect(actual_rules).to eq(rules)
      system("exit 0") # setup $?
    end
  end

  def expect_cf_sg_create(name, rules)
    expect_cf_sg_write(name, rules, 'create-security-group')
  end

  def expect_cf_sg_update(name, rules)
    expect_cf_sg_write(name, rules, 'update-security-group')
  end

  def expect_cf_bind_sg(type, name)
    expect(subject).to receive(:system).with("cf", "bind-#{type}-security-group", name) do
      system("exit 0") # setup $?
    end
  end
end
