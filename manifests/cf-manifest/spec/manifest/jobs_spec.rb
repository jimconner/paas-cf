RSpec.describe "the global update block" do
  let(:manifest) { manifest_with_defaults }

  describe "in order to run parallel deployment by default" do
    it "has serial false" do
      expect(manifest["update"]["serial"]).to be false
    end
  end
end

RSpec.describe "the jobs definitions block" do
  let(:jobs) { manifest_with_defaults["jobs"] }

  def get_job(job_name)
    jobs.select { |j| j["name"] == job_name }.first
  end

  matcher :be_updated_serially do
    match do |job_name|
      get_job(job_name)["update"]["serial"]
    end
  end

  matcher :be_ordered_before do |later_job|
    match do |earlier_job|
      jobs.index { |j| j["name"] == earlier_job } < jobs.index { |j| j["name"] == later_job }
    end
  end

  describe "in order to enforce etcd dependency on NATS" do
    it "has etcd serial" do
      expect("etcd").to be_updated_serially
    end

    it "has nats before etcd" do
      expect("nats").to be_ordered_before("etcd")
    end
  end

  describe "in order to start/upgrade etcd cluster while maintaining consensus" do
    it "has etcd serial" do
      expect("etcd").to be_updated_serially
    end
  end

  describe "in order to start one consul master for consensus" do
    it "has consul serial" do
      expect("consul").to be_updated_serially
    end

    specify "has consul first" do
      expect(jobs[0]["name"]).to eq("consul")
    end
  end

  describe "in order to apply BBS migrations before upgrading the cells" do
    it "has database before the cells" do
      expect("database").to be_ordered_before("cell")
    end

    it "has database serial" do
      expect("database").to be_updated_serially
    end
  end

  describe "in order to match the upstream Diego job ordering" do
    it "has database before brain" do
      expect("database").to be_ordered_before("brain")
    end

    it "has brain before the cells" do
      expect("brain").to be_ordered_before("cell")
    end

    it "has the cells before cc_bridge" do
      expect("cell").to be_ordered_before("cc_bridge")
    end

    it "has cc_bridge before route_emitter" do
      expect("cc_bridge").to be_ordered_before("route_emitter")
    end

    it "has route_emitter before access" do
      expect("route_emitter").to be_ordered_before("access")
    end
  end

  it "should list consul_agent first if present" do
    jobs_with_consul = jobs.select { |j|
      not j["templates"].select { |t|
        t["name"] == "consul_agent"
      }.empty?
    }

    jobs_with_consul.each { |j|
      expect(j["templates"].first["name"]).to eq("consul_agent"),
        "expected '#{j['name']}' job to list 'consul_agent' first"
    }
  end
end
