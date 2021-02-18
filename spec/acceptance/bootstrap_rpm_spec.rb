require 'spec_helper_acceptance'

describe 'bootstrap_rpm', :order => :defined do

  before(:suite) do
    on hosts, 'rm -rf /var/www/html/pub/*rpm'
  end

  context 'with default params' do
    let(:pp) do
      <<-EOS
      include foreman_proxy_content::bootstrap_rpm

      package { "katello-ca-consumer-#{host_inventory['fqdn']}":
        ensure => installed,
        source => "/var/www/html/pub/katello-ca-consumer-#{host_inventory['fqdn']}-1.0-1.noarch.rpm",
        require => Class['foreman_proxy_content::bootstrap_rpm'],
      }
      EOS
    end

    it_behaves_like 'a idempotent resource'

    describe file('/var/www/html/pub/katello-rhsm-consumer') do
      it { should be_file }
      it { should be_mode 755 }
      it { should be_owned_by 'root' }
      it { should be_grouped_into 'root' }
    end

    describe file("/var/www/html/pub/katello-ca-consumer-#{host_inventory['fqdn']}-1.0-1.noarch.rpm") do
      it { should be_file }
    end

    describe file('/var/www/html/pub/katello-ca-consumer-latest.noarch.rpm') do
      it { should be_symlink }
      it { should be_linked_to "/var/www/html/pub/katello-ca-consumer-#{host_inventory['fqdn']}-1.0-1.noarch.rpm" }
    end

    describe file('/var/www/html/pub/katello-server-ca.crt') do
      it { should be_file }
      it { should be_mode 644 }
      it { should be_owned_by 'root' }
      it { should be_grouped_into 'root' }
    end

    describe command('rpm -qp /var/www/html/pub/katello-ca-consumer-latest.noarch.rpm --requires') do
      its(:stdout) { should match(/^subscription-manager/) }
    end

    describe command('rpm -qp /var/www/html/pub/katello-ca-consumer-latest.noarch.rpm --list') do
      its(:stdout) { should match(/^\/usr\/bin\/katello-rhsm-consumer/) }
    end

    describe x509_certificate('/etc/rhsm/ca/katello-server-ca.pem') do
      it { should be_certificate }
    end

    describe x509_certificate('/etc/rhsm/ca/katello-default-ca.pem') do
      it { should be_certificate }
    end

    describe file('/etc/rhsm/rhsm.conf') do
      its(:content) { should match /repo_ca_cert = %\(ca_cert_dir\)skatello-server-ca.pem/ }
      its(:content) { should match /prefix = \/rhsm/ }
      its(:content) { should match /full_refresh_on_yum = 1/ }
      its(:content) { should match /package_profile_on_trans = 1/ }
      its(:content) { should match /hostname = #{host_inventory['fqdn']}/ }
      its(:content) { should match %r{baseurl = https://#{host_inventory['fqdn']}/pulp/content/} }
      its(:content) { should match /port = 443/ }
    end
  end

  context 'creates new RPM after CA changes' do
    let(:pp) do
      <<-EOS
      include foreman_proxy_content::bootstrap_rpm

      package { "katello-ca-consumer-#{host_inventory['fqdn']}":
        ensure => latest,
        source => "/var/www/html/pub/katello-ca-consumer-latest.noarch.rpm",
        require => Class['foreman_proxy_content::bootstrap_rpm'],
      }
      EOS
    end

    before(:all) do
      pp_setup = <<-EOS
        exec { "rm -rf /root/ssl-build":
          path => "/bin:/usr/bin",
        }
      EOS

      apply_manifest(pp_setup, catch_failures: true)
    end

    it_behaves_like 'a idempotent resource'

    describe file("/var/www/html/pub/katello-ca-consumer-#{host_inventory['fqdn']}-1.0-2.noarch.rpm") do
      it { should be_file }
    end

    describe file('/var/www/html/pub/katello-ca-consumer-latest.noarch.rpm') do
      it { should be_symlink }
      it { should be_linked_to "/var/www/html/pub/katello-ca-consumer-#{host_inventory['fqdn']}-1.0-2.noarch.rpm" }
    end

    describe file('/var/www/html/pub/katello-rhsm-consumer') do
      it { should be_file }
      it { should be_mode 755 }
      it { should be_owned_by 'root' }
      it { should be_grouped_into 'root' }
    end
  end

  context 'creates new RPM after port changes' do
    let(:pp) do
      <<-EOS
      class { 'foreman_proxy_content::bootstrap_rpm':
        rhsm_port => 8443,
      }

      package { "katello-ca-consumer-#{host_inventory['fqdn']}":
        ensure => latest,
        source => "/var/www/html/pub/katello-ca-consumer-latest.noarch.rpm",
        require => Class['foreman_proxy_content::bootstrap_rpm'],
      }
      EOS
    end

    it_behaves_like 'a idempotent resource'

    describe file("/var/www/html/pub/katello-ca-consumer-#{host_inventory['fqdn']}-1.0-3.noarch.rpm") do
      it { should be_file }
    end

    describe file('/var/www/html/pub/katello-ca-consumer-latest.noarch.rpm') do
      it { should be_symlink }
      it { should be_linked_to "/var/www/html/pub/katello-ca-consumer-#{host_inventory['fqdn']}-1.0-3.noarch.rpm" }
    end

    describe file('/var/www/html/pub/katello-rhsm-consumer') do
      it { should be_file }
      it { should be_mode 755 }
      it { should be_owned_by 'root' }
      it { should be_grouped_into 'root' }
      its(:content) { should match(/8443/) }
    end

    describe file('/etc/rhsm/rhsm.conf') do
      its(:content) { should match /repo_ca_cert = %\(ca_cert_dir\)skatello-server-ca.pem/ }
      its(:content) { should match /prefix = \/rhsm/ }
      its(:content) { should match /full_refresh_on_yum = 1/ }
      its(:content) { should match /package_profile_on_trans = 1/ }
      its(:content) { should match /hostname = #{host_inventory['fqdn']}/ }
      its(:content) { should match %r{baseurl = https://#{host_inventory['fqdn']}/pulp/content/} }
      its(:content) { should match /port = 443/ }
    end
  end
end
