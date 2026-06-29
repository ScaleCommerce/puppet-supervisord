# Class: supervisord::config
#
# Configuration class for supervisor init and conf directories
#
# When the node's backend is 'zpinit' this is a no-op: there is no supervisord
# daemon, so its config dirs, supervisord.conf and init script are not managed
# (and reload is not notified -- which is what was driving supervisorctl on
# zpinit nodes). The class is still declared so the anchor chain in init.pp
# resolves. Backend is auto-detected (see init.pp $service_manager) and
# overridable via sc::service_manager.
#
class supervisord::config inherits supervisord {

  unless $supervisord::service_manager == 'zpinit' {

  if ($supervisord::manage_config) {
    file { $supervisord::config_include:
      ensure  => directory,
      owner   => $supervisord::user,
      group   => $supervisord::group,
      mode    => '0755',
      recurse => $supervisord::config_include_purge,
      purge   => $supervisord::config_include_purge,
      notify  => Class['supervisord::reload'],
    }
  }

  file { $supervisord::log_path:
    ensure => directory,
    owner  => $supervisord::user,
    group  => $supervisord::group,
    mode   => '0644'
  }

  if $supervisord::run_path != '/var/run' {
    file { $supervisord::run_path:
      ensure => directory,
      owner  => $supervisord::user,
      group  => $supervisord::group,
      mode   => '0755'
    }
  }

  if $supervisord::install_init {
    file { $supervisord::init_script:
      ensure  => present,
      owner   => 'root',
      mode    => $supervisord::init_mode,
      content => template($supervisord::init_script_template),
      notify  => Class['supervisord::service'],
    }

    if $supervisord::init_defaults {
      file { $supervisord::init_defaults:
        ensure  => present,
        owner   => 'root',
        mode    => '0755',
        content => template($supervisord::init_defaults_template),
        notify  => Class['supervisord::service'],
      }
    }
  }

  if ($supervisord::manage_config) {
    concat { $supervisord::config_file:
      owner  => 'root',
      group  => '0',
      mode   => $supervisord::config_file_mode,
      notify => Class['supervisord::service']
    }

    if $supervisord::unix_socket {
      concat::fragment { 'supervisord_unix':
        target  => $supervisord::config_file,
        content => template('supervisord/supervisord_unix.erb'),
        order   => '01'
      }
    }

    if $supervisord::inet_server {
      concat::fragment { 'supervisord_inet':
        target  => $supervisord::config_file,
        content => template('supervisord/supervisord_inet.erb'),
        order   => '01'
      }
    }

    if $supervisord::use_ctl_socket {
      concat::fragment { 'supervisord_ctl':
        target  => $supervisord::config_file,
        content => template('supervisord/supervisord_ctl.erb'),
        order   => '02'
      }
    }

    concat::fragment { 'supervisord_main':
      target  => $supervisord::config_file,
      content => template('supervisord/supervisord_main.erb'),
      order   => '03'
    }
  }

  }
}
