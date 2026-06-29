# Class: supervisord::reload
#
# Class to reread and update supervisord with supervisorctl
#
# When the node's backend is 'zpinit' this is a no-op: there is no supervisord
# daemon and no supervisorctl to call. The class is still declared (and is a
# harmless refresh target for config.pp) so existing notify/anchor references
# resolve. Backend is auto-detected (see init.pp $service_manager) and
# overridable via sc::service_manager.
#
class supervisord::reload inherits supervisord {
  unless $supervisord::service_manager == 'zpinit' {
    $supervisorctl = $::supervisord::executable_ctl

    exec { 'supervisorctl_reread':
      command     => "${supervisorctl} reread",
      refreshonly => true,
    }
    exec { 'supervisorctl_update':
      command     => "${supervisorctl} update",
      refreshonly => true,
    }
  }
}

