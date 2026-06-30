# Class supervisord::install
#
# Installs supervisor package (defaults to using pip)
#
# On a zpinit node the supervisord daemon is not installed (zpinit is PID 1).
# Instead we drop a supervisorctl -> zpctl compatibility symlink so any legacy
# caller still invoking `supervisorctl` (scripts, third-party tooling, cron
# jobs) transparently drives zpinit; zpctl implements the same verbs
# (status/start/stop/restart/update). The class is always declared so the
# anchor chain in init.pp resolves. Backend is auto-detected (see init.pp
# $service_manager) and overridable via sc::service_manager.
#
class supervisord::install inherits supervisord {
  if $supervisord::service_manager == 'zpinit' {
    file { '/usr/local/bin/supervisorctl':
      ensure => link,
      target => '/usr/local/bin/zpctl',
    }
  } else {
    # Check if supervisord is already installed in the system (not in venv)
    # This prevents reinstallation via pip in new venv when old system Python installation exists
    exec { 'check-supervisord-installed':
      command => 'which supervisorctl || which supervisord',
      path    => ['/usr/bin', '/bin', '/usr/local/bin'],
      returns => [0, 1],
      onlyif  => 'test -z "$(which supervisorctl 2>/dev/null)" && test -z "$(which supervisord 2>/dev/null)"',
    }

    if $::supervisord::pip_proxy and $::supervisord::package_provider == 'pip' {
      exec { 'pip-install-supervisor':
        user        => root,
        path        => ['/usr/bin','/bin'],
        environment => [ "http_proxy=${supervisord::pip_proxy}", "https_proxy=${supervisord::pip_proxy}" ],
        command     => "pip install ${supervisord::package_name}",
        unless      => 'which supervisorctl',
      }
    }
    elsif $::supervisord::package_provider == 'pipx' {
      exec { 'pipx-install-supervisor':
        user        => root,
        path        => ['/usr/bin','/bin', '/usr/local/bin'],
        command     => "pipx install ${supervisord::package_name}",
        unless      => 'which supervisorctl',
        require     => Package['pipx'],
      }
      file { '/usr/local/bin/supervisord':
        ensure => link,
        target => '/root/.local/bin/supervisord',
      }
      file { '/usr/local/bin/supervisorctl':
        ensure => link,
        target => '/root/.local/bin/supervisorctl',
      }
    }
    else {
      if $::supervisord::package_provider == 'pip' {
        # Check if supervisord is already available in system PATH
        # This prevents reinstallation via pip in new venv when old system Python installation exists
        notify { 'supervisord already installed in system via pip, skipping installation': loglevel => 'debug' }
      }
      else {
        package { $supervisord::package_name:
          ensure          => $supervisord::package_ensure,
          provider        => $supervisord::package_provider,
          install_options => $supervisord::package_install_options,
        }
      }
    }
  }
}
