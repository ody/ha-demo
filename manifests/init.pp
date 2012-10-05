class demo {

  package { 'nginx': ensure => present, }

  class { 'corosync':
    enable_secauth    => true,
    bind_address      => $ipaddress,
    multicast_address => '239.1.1.2',
  }
  corosync::service { 'pacemaker':
    version => '0',
    notify  => Service['corosync'],
    require => Class['corosync'],
  }

  Cs_property { require => Corosync::Service['pacemaker'], }

  cs_property { 'no-quorum_policy':    value => 'ignore', }
  cs_property { 'stonith-enabled':     value => 'false', }
  cs_property { 'resource-stickiness': value => '100', }

  Cs_primitive {
    operations => { 'monitor' => '10s' },
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
    parameters      => { 'ip' => '172.16.210.100', 'cidr_netmask' => '32' },
  }

  cs_primitive { 'nginx_service':
    primitive_class => 'lsb',
    primitive_type  => 'nginx',
    provided_by     => 'heartbeat',
    require         => Cs_primitive['nginx_vip'],
  }

  cs_group { 'ha_web':
    primitives => [ 'nginx_vip', 'nginx_service' ],
  }
}
