# Class: supervisord::service
#
# Class for the supervisord service
#
# When the node's backend is 'zpinit' this is a no-op: the supervisord daemon
# service is not managed (zpinit supervises processes instead). The class is
# still declared so the anchor chain in init.pp resolves. Backend is
# auto-detected (see init.pp $service_manager) and overridable via
# sc::service_manager.
#
class supervisord::service inherits supervisord  {
  if $::supervisord::service_manage and $supervisord::service_manager != 'zpinit' {
    if $::supervisord::init_type == 'systemd' {
      exec { 'refresh_supervisord_unit':
        command     => '/usr/bin/env systemctl daemon-reload',
        refreshonly => true,
        before      => Service[$::supervisord::service_name],
      }
    }

    service { $::supervisord::service_name:
      ensure     => $::supervisord::service_ensure,
      enable     => $::supervisord::service_enable,
      hasrestart => true,
      hasstatus  => true,
      restart    => $::supervisord::service_restart,
    }
  }
}
