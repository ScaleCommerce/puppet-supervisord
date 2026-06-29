# Class supervisord::install
#
# Installs supervisor package (defaults to using pip)
#
# When sc::service_manager is 'zpinit' this is a no-op: the supervisord daemon
# is not installed (zpinit is PID 1). The class is still declared so the
# anchor chain in init.pp resolves.
#
class supervisord::install inherits supervisord {
  $_service_manager = lookup('sc::service_manager', Enum['supervisor', 'zpinit'], 'first', 'supervisor')

  unless $_service_manager == 'zpinit' {
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
