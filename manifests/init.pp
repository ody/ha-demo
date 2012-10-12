class demo {

  package { 'nginx': ensure => present, }

  class { 'corosync':
    enable_secauth    => true,
    authkey           => '/var/lib/puppet/ssl/certs/ca.pem',
    bind_address      => $ipaddress,
    multicast_address => '239.1.1.2',
  }

  service { 'pacemaker':
    ensure  => stopped,
    enable  => false,
    require => Package['pacemaker'],
  }

  corosync::service { 'pacemaker':
    version => '0',
    notify  => Service['corosync'],
    require => Service['pacemaker'],
  }

  Cs_property { require => Corosync::Service['pacemaker'], }

  cs_property { 'no-quorum_policy':    value => 'ignore', }
  cs_property { 'stonith-enabled':     value => 'false', }
  cs_property { 'resource-stickiness': value => '100', }

  Cs_primitive {
    require    => [
      Package['nginx'],
      Cs_property['no-quorum_policy'],
      Cs_property['stonith-enabled'],
      Cs_property['resource-stickiness']
    ],
  }

  cs_primitive { 'nginx_vip':
    primitive_class => 'ocf',
    primitive_type  => 'IPaddr2',
    provided_by     => 'heartbeat',
    parameters      => { 'ip' => '172.16.210.100', 'cidr_netmask' => '24' },
    operations      => { 'monitor' => { 'interval' => '10s' } },
  }

  cs_primitive { 'nginx_service':
    primitive_class => 'lsb',
    primitive_type  => 'nginx',
    provided_by     => 'heartbeat',
    operations      => {
      'monitor' => { 'interval' => '10s', 'timeout' => '30s' },
      'start'   => { 'interval' => '0', 'timeout' => '30s', 'on-fail' => 'restart' }
    },
    require         => Cs_primitive['nginx_vip'],
  }

  cs_colocation { 'vip_with_service':
    primitives => [ 'nginx_vip', 'nginx_service' ],
  }
  cs_order { 'vip_before_service':
    first   => 'nginx_vip',
    second  => 'nginx_service',
    require => Cs_colocation['vip_with_service'],
  }

  include corosync::reprobe
}
