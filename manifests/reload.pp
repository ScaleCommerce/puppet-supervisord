# Class: supervisord::reload
#
# Loads added/changed program definitions into the running supervisor. Backend
# is auto-detected (see init.pp $service_manager) and overridable via
# sc::service_manager.
#
# On supervisord this runs `supervisorctl reread && update`. On zpinit it runs
# the equivalent `zpctl update` (global config reload: starts added services,
# stops removed, restarts changed -- see zpinit cmdUpdate). This matters because
# zpinit does NOT pick up newly written service TOMLs on its own during a Puppet
# run, so a program declared via supervisord::program that has no separate
# Service[name] (e.g. cron, gitlab-runner, rundeck-node-consul-*) would
# otherwise sit on disk unloaded until the next zpinit restart. program.pp
# notifies this class when a program's config (conf or TOML) changes, on both
# backends. Refreshonly + idempotent, so it is safe alongside the per-service
# reload the zpinit Service provider already does for managed services.
#
class supervisord::reload inherits supervisord {
  if $supervisord::service_manager == 'zpinit' {
    exec { 'zpctl_update':
      command     => 'zpctl update',
      path        => ['/usr/local/sbin', '/usr/local/bin', '/usr/sbin', '/usr/bin', '/sbin', '/bin'],
      refreshonly => true,
    }
  } else {
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

