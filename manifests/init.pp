# == Class: foreman_proxy_content
#
# Configure content for foreman proxy for use by katello
#
# === Parameters:
#
# $parent_fqdn::                        FQDN of the parent node.
#                                       type:String
#
# $enable_ostree::                      Boolean to enable ostree plugin. This requires existence of an ostree install.
#                                       type:Boolean
#
# $certs_tar::                          Path to a tar with certs for the node
#                                       type:Optional[Stdlib::Absolutepath]
#
# === Advanced parameters:
#
# $puppet::                             Enable puppet
#                                       type:Boolean
#
# $pulp_master::                        Whether the foreman_proxy_content should be identified as a pulp master server
#                                       type:Boolean
#
# $pulp_admin_password::                Password for the Pulp admin user. It should be left blank so that a random password is generated
#                                       type:String
#
# $pulp_oauth_effective_user::          User to be used for Pulp REST interaction
#                                       type:String
#
# $pulp_oauth_key::                     OAuth key to be used for Pulp REST interaction
#                                       type:String
#
# $pulp_oauth_secret::                  OAuth secret to be used for Pulp REST interaction
#                                       type:Optional[String]
#
# $pulp_max_speed::                     The maximum download speed per second for a Pulp task, such as a sync. (e.g. "4 Kb" (Uses SI KB), 4MB, or 1GB" )
#                                       type:Optional[String]
#
# $reverse_proxy::                      Add reverse proxy to the parent
#                                       type:Boolean
#
# $reverse_proxy_port::                 Reverse proxy listening port
#                                       type:Integer[0, 65535]
#
# $rhsm_url::                           The URL that the RHSM API is rooted at
#                                       type:String
#
# $qpid_router::                        Configure qpid dispatch router
#                                       type:Boolean
#
# $qpid_router_hub_addr::               Address for dispatch router hub
#                                       type:String
#
# $qpid_router_hub_port::               Port for dispatch router hub
#                                       type:Integer[0, 65535]
#
# $qpid_router_agent_addr::             Listener address for goferd agents
#                                       type:String
#
# $qpid_router_agent_port::             Listener port for goferd agents
#                                       type:Integer[0, 65535]
#
# $qpid_router_broker_addr::            Address of qpidd broker to connect to
#                                       type:String
#
# $qpid_router_broker_port::            Port of qpidd broker to connect to
#                                       type:Integer[0, 65535]
#
# $qpid_router_logging_level::          Logging level of dispatch router (e.g. info+ or debug+)
#                                       type:String
#
# $qpid_router_logging_path::           Directory for dispatch router logs
#                                       type:Stdlib::Absolutepath
#
class foreman_proxy_content (
  $parent_fqdn                  = $foreman_proxy_content::params::parent_fqdn,
  $certs_tar                    = $foreman_proxy_content::params::certs_tar,
  $pulp_master                  = $foreman_proxy_content::params::pulp_master,
  $pulp_admin_password          = $foreman_proxy_content::params::pulp_admin_password,
  $pulp_oauth_effective_user    = $foreman_proxy_content::params::pulp_oauth_effective_user,
  $pulp_oauth_key               = $foreman_proxy_content::params::pulp_oauth_key,
  $pulp_oauth_secret            = $foreman_proxy_content::params::pulp_oauth_secret,
  $pulp_max_speed               = $foreman_proxy_content::params::pulp_max_speed,

  $puppet                       = $foreman_proxy_content::params::puppet,

  $reverse_proxy                = $foreman_proxy_content::params::reverse_proxy,
  $reverse_proxy_port           = $foreman_proxy_content::params::reverse_proxy_port,

  $rhsm_url                     = $foreman_proxy_content::params::rhsm_url,

  $qpid_router                  = $foreman_proxy_content::params::qpid_router,
  $qpid_router_hub_addr         = $foreman_proxy_content::params::qpid_router_hub_addr,
  $qpid_router_hub_port         = $foreman_proxy_content::params::qpid_router_hub_port,
  $qpid_router_agent_addr       = $foreman_proxy_content::params::qpid_router_agent_addr,
  $qpid_router_agent_port       = $foreman_proxy_content::params::qpid_router_agent_port,
  $qpid_router_broker_addr      = $foreman_proxy_content::params::qpid_router_broker_addr,
  $qpid_router_broker_port      = $foreman_proxy_content::params::qpid_router_broker_port,
  $qpid_router_logging_level    = $foreman_proxy_content::params::qpid_router_logging_level,
  $qpid_router_logging_path     = $foreman_proxy_content::params::qpid_router_logging_path,
  $enable_ostree                = $foreman_proxy_content::params::enable_ostree,
) inherits foreman_proxy_content::params {
  validate_bool($enable_ostree)

  include ::certs
  include ::foreman_proxy
  include ::foreman_proxy::plugin::pulp

  validate_present($foreman_proxy_content::parent_fqdn)
  validate_absolute_path($foreman_proxy_content::qpid_router_logging_path)

  $pulp = $::foreman_proxy::plugin::pulp::pulpnode_enabled
  if $pulp {
    validate_present($pulp_oauth_secret)
  }

  $foreman_proxy_fqdn = $::fqdn
  $foreman_url = "https://${parent_fqdn}"
  $reverse_proxy_real = $pulp or $reverse_proxy

  $rhsm_port = $reverse_proxy_real ? {
    true  => $reverse_proxy_port,
    false => '443'
  }

  package{ ['katello-debug', 'katello-client-bootstrap']:
    ensure => installed,
  }

  class { '::certs::foreman_proxy':
    hostname => $foreman_proxy_fqdn,
    require  => Package['foreman-proxy'],
    notify   => Service['foreman-proxy'],
  } ~>
  class { '::certs::katello':
    deployment_url => $foreman_proxy_content::rhsm_url,
    rhsm_port      => $foreman_proxy_content::rhsm_port,
  }

  if $pulp or $reverse_proxy_real {
    class { '::certs::apache':
      hostname => $foreman_proxy_fqdn,
    } ~>
    Class['certs::foreman_proxy'] ~>
    class { '::foreman_proxy_content::reverse_proxy':
      path => '/',
      url  => "${foreman_url}/",
      port => $foreman_proxy_content::reverse_proxy_port,
    }
  }

  if $pulp_master or $pulp {
    if $qpid_router {
      class { '::foreman_proxy_content::dispatch_router':
        require => Class['pulp'],
      }
    }

    class { '::pulp::crane':
      cert    => $certs::apache::apache_cert,
      key     => $certs::apache::apache_key,
      ca_cert => $certs::ca_cert,
      require => Class['certs::apache'],
    }
  }

  if $pulp {
    include ::apache
    $apache_version = $::apache::apache_version

    file {'/etc/httpd/conf.d/pulp_nodes.conf':
      ensure  => file,
      content => template('foreman_proxy_content/pulp_nodes.conf.erb'),
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
    }

    apache::vhost { 'foreman_proxy_content':
      servername      => $foreman_proxy_fqdn,
      port            => 80,
      priority        => '05',
      docroot         => '/var/www/html',
      options         => ['SymLinksIfOwnerMatch'],
      custom_fragment => template('foreman_proxy_content/_pulp_includes.erb', 'foreman_proxy_content/httpd_pub.erb'),
    }

    class { '::certs::qpid': } ~>
    class { '::certs::qpid_client': } ~>
    class { '::qpid':
      ssl                    => true,
      ssl_cert_db            => $::certs::nss_db_dir,
      ssl_cert_password_file => $::certs::qpid::nss_db_password_file,
      ssl_cert_name          => 'broker',
      interface              => 'lo',
    } ~>
    class { '::pulp':
      enable_rpm                => true,
      enable_puppet             => true,
      enable_docker             => true,
      enable_ostree             => $enable_ostree,
      default_password          => $pulp_admin_password,
      oauth_enabled             => true,
      oauth_key                 => $pulp_oauth_key,
      oauth_secret              => $pulp_oauth_secret,
      messaging_transport       => 'qpid',
      messaging_auth_enabled    => false,
      messaging_ca_cert         => $certs::ca_cert,
      messaging_client_cert     => $certs::params::messaging_client_cert,
      messaging_url             => "ssl://${qpid_router_broker_addr}:${qpid_router_broker_port}",
      broker_url                => "qpid://${qpid_router_broker_addr}:${qpid_router_broker_port}",
      broker_use_ssl            => true,
      manage_broker             => false,
      manage_httpd              => true,
      manage_plugins_httpd      => true,
      manage_squid              => true,
      repo_auth                 => true,
      node_oauth_effective_user => $pulp_oauth_effective_user,
      node_oauth_key            => $pulp_oauth_key,
      node_oauth_secret         => $pulp_oauth_secret,
      node_server_ca_cert       => $certs::params::pulp_server_ca_cert,
      https_cert                => $certs::apache::apache_cert,
      https_key                 => $certs::apache::apache_key,
      ca_cert                   => $certs::ca_cert,
      crane_data_dir            => '/var/lib/pulp/published/docker/v2/app',
      yum_max_speed             => $pulp_max_speed,
    }

    pulp::apache::fragment{'gpg_key_proxy':
      ssl_content => template('foreman_proxy_content/_pulp_gpg_proxy.erb'),
    }
  }

  if $puppet {
    # We can't pull the certs out to the top level, because of how it gets the default
    # parameter values from the main ::certs class.  Kafo can't handle that case, so
    # it remains here for now.
    class { '::certs::puppet':
      hostname => $foreman_proxy_fqdn,
      notify   => Class['puppet'],
    }
  }

  if $certs_tar {
    certs::tar_extract { $foreman_proxy_content::certs_tar: } -> Class['certs']
    Certs::Tar_extract[$certs_tar] -> Class['certs::foreman_proxy']

    if $reverse_proxy_real or $pulp {
      Certs::Tar_extract[$certs_tar] -> Class['certs::apache']
    }

    if $pulp {
      Certs::Tar_extract[$certs_tar] -> Class['certs'] -> Class['::certs::qpid']
    }

    if $puppet {
      Certs::Tar_extract[$certs_tar] -> Class['certs::puppet']
    }
  }
}
