# Manages the pub httpd directory where
# e.g. the katello ca certificate is available
# for download
class foreman_proxy_content::pub_dir (
  String $servername = $facts['fqdn'],
  String $pub_dir_options = '+FollowSymLinks +Indexes',
) {
  include foreman_proxy_content
  include apache

  ensure_packages('katello-client-bootstrap')

  apache::vhost { 'foreman_proxy_content':
    servername          => $servername,
    port                => 80,
    priority            => '05',
    docroot             => '/var/www/html',
    options             => ['SymLinksIfOwnerMatch'],
    additional_includes => ["${apache::confd_dir}/pulp-vhosts80/*.conf"],
    custom_fragment     => template('foreman_proxy_content/httpd_pub.erb'),
  }
}
