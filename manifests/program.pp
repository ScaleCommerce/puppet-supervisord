# Define: supervisord::program
#
# This define creates an program configuration file
#
# Documentation on parameters available at:
# http://supervisord.org/configuration.html#program-x-section-settings
#
define supervisord::program(
  $command,
  $ensure                  = present,
  $ensure_process          = 'running',
  $cfgreload               = undef,
  $env_var                 = undef,
  $process_name            = undef,
  $numprocs                = undef,
  $numprocs_start          = undef,
  $priority                = undef,
  $autostart               = undef,
  $autorestart             = undef,
  $startsecs               = undef,
  $startretries            = undef,
  $exitcodes               = undef,
  $stopsignal              = undef,
  $stopwaitsecs            = undef,
  $stopasgroup             = undef,
  $killasgroup             = undef,
  $user                    = undef,
  $redirect_stderr         = undef,
  $stdout_logfile          = "program_${name}.log",
  $stdout_logfile_maxbytes = undef,
  $stdout_logfile_backups  = undef,
  $stdout_capture_maxbytes = undef,
  $stdout_events_enabled   = undef,
  $stderr_logfile          = "program_${name}.error",
  $stderr_logfile_maxbytes = undef,
  $stderr_logfile_backups  = undef,
  $stderr_capture_maxbytes = undef,
  $stderr_events_enabled   = undef,
  $program_environment     = undef,
  $environment             = undef,
  $directory               = undef,
  $umask                   = undef,
  $serverurl               = undef,
  $config_file_mode        = '0644'
) {

  include supervisord

# parameter validation
  validate_string($command)
  validate_re($ensure_process, ['running', 'stopped', 'removed', 'unmanaged'])
  if $cfgreload { validate_bool($cfgreload) }
  if $process_name { validate_string($process_name) }
  if $numprocs { if !is_integer($numprocs) { validate_re($numprocs, '^\d+')} }
  if $numprocs_start { if !is_integer($numprocs_start) { validate_re($numprocs_start, '^\d+')} }
  if $priority { if !is_integer($priority) { validate_re($priority, '^\d+') } }
  if $autostart { if !is_bool($autostart) { validate_re($autostart, ['true', 'false']) } }
  if $autorestart { if !is_bool($autorestart) { validate_re($autorestart, ['true', 'false', 'unexpected']) } }
  if $startsecs { if !is_integer($startsecs) { validate_re($startsecs, '^\d+')} }
  if $startretries { if !is_integer($startretries) { validate_re($startretries, '^\d+')} }
  if $exitcodes { validate_string($exitcodes)}
  if $stopsignal { validate_re($stopsignal, ['TERM', 'HUP', 'INT', 'QUIT', 'KILL', 'USR1', 'USR2']) }
  if $stopwaitsecs { if !is_integer($stopwaitsecs) { validate_re($stopwaitsecs, '^\d+')} }
  if $stopasgroup { validate_bool($stopasgroup) }
  if $killasgroup { validate_bool($killasgroup) }
  if $user { validate_string($user) }
  if $redirect_stderr { validate_bool($redirect_stderr) }
  validate_string($stdout_logfile)
  if $stdout_logfile_maxbytes { validate_string($stdout_logfile_maxbytes) }
  if $stdout_logfile_backups { if !is_integer($stdout_logfile_backups) { validate_re($stdout_logfile_backups, '^\d+')} }
  if $stdout_capture_maxbytes { validate_string($stdout_capture_maxbytes) }
  if $stdout_events_enabled { validate_bool($stdout_events_enabled) }
  validate_string($stderr_logfile)
  if $stderr_logfile_maxbytes { validate_string($stderr_logfile_maxbytes) }
  if $stderr_logfile_backups { if !is_integer($stderr_logfile_backups) { validate_re($stderr_logfile_backups, '^\d+')} }
  if $stderr_capture_maxbytes { validate_string($stderr_capture_maxbytes) }
  if $stderr_events_enabled { validate_bool($stderr_events_enabled) }
  if $directory { validate_absolute_path($directory) }
  if $umask { validate_re($umask, '^[0-7][0-7][0-7]$') }
  validate_re($config_file_mode, '^0[0-7][0-7][0-7]$')

  # create the correct log variables
  $stdout_logfile_path = $stdout_logfile ? {
        /(NONE|AUTO|syslog)/ => $stdout_logfile,
        /^\//                => $stdout_logfile,
        default              => "${supervisord::log_path}/${stdout_logfile}",
  }

  $stderr_logfile_path = $stderr_logfile ? {
        /(NONE|AUTO|syslog)/ => $stderr_logfile,
        /^\//                => $stderr_logfile,
        default              => "${supervisord::log_path}/${stderr_logfile}",
  }

  # Handle deprecated $environment variable
  if $environment { notify {'[supervisord] *** DEPRECATED WARNING ***: $program_environment has replaced $environment':}}
  $_program_environment = $program_environment ? {
    undef   => $environment,
    default => $program_environment
  }

  # convert environment data into a csv
  if $env_var {
    $env_hash = hiera_hash($env_var)
    validate_hash($env_hash)
    $env_string = hash2csv($env_hash)
  }
  elsif $_program_environment {
    validate_hash($_program_environment)
    $env_string = hash2csv($_program_environment)
  }

  # Reload default with override
  $_cfgreload = $cfgreload ? {
    undef   => $supervisord::cfgreload_program,
    default => $cfgreload
  }

  # Backend selection. When the node's backend is 'zpinit', emit a zpinit
  # service TOML instead of supervisord config / supervisorctl resources. The
  # Supervisord::Program[$title] resource still exists (this define), so existing
  # `before/require/notify => Supervisord::Program[X]` references keep resolving
  # on both backends -- no data rewrite needed. This is a transitional shim while
  # the fleet migrates off supervisord. The backend is auto-detected (see
  # supervisord/init.pp $service_manager) and overridable via sc::service_manager.
  $_service_manager = $supervisord::service_manager

  if $_service_manager == 'zpinit' {
    # zpinit::service accepts supervisord parameter names; drop undef so strict
    # zpinit::service params (e.g. priority Integer[0,9999] default 50) fall back
    # to their defaults. stdout/stderr logfile + redirect_stderr are
    # intentionally NOT passed: their supervisord defaults are relative filenames
    # that would become a bogus zpinit [log] path, and zpinit should inherit the
    # container's stdout/stderr by default.
    $_zpinit_params = {
      'command'             => $command,
      'ensure'              => $ensure,
      'autostart'           => $autostart,
      'autorestart'         => $autorestart,
      'user'                => $user,
      'numprocs'            => $numprocs,
      'stopsignal'          => $stopsignal,
      'stopwaitsecs'        => $stopwaitsecs,
      'directory'           => $directory,
      'environment'         => $environment,
      'program_environment' => $program_environment,
      'env_var'             => $env_var,
      'priority'            => $priority,
      'ensure_process'      => $ensure_process,
    }.filter |$k, $v| { $v =~ NotUndef }
    # zpinit::service writes the TOML and (when it declares no Service of its
    # own) notifies zpinit::reload to run `zpctl update`, so a new/changed
    # program is loaded into the running set without a backend-specific step
    # here. Loading is owned by the zpinit module, not this dispatch shim.
    zpinit::service { $name: * => $_zpinit_params }
  } else {
    $conf = "${supervisord::config_include}/program_${name}.conf"

    file { $conf:
      ensure  => $ensure,
      owner   => 'root',
      mode    => $config_file_mode,
      content => template('supervisord/conf/program.erb'),
    }

    if $_cfgreload {
      File[$conf] {
        notify => Class['supervisord::reload'],
      }
    }

    # supervisorctl target. A program is a homogeneous process group (members
    # named "<name>:<process_name>") whenever numprocs > 1 OR process_name
    # contains %(process_num) -- the latter can happen at numprocs == 1 via an
    # explicit process_name, in which case the bare name is not addressable and
    # supervisorctl reports "no such process". Use the ":*" group form for both.
    if $numprocs != 1 or ($process_name and $process_name =~ /%\(process_num\)/) {
      $pname = "${name}:*"
    }
    else {
      $pname = $name
    }

    case $ensure_process {
      'stopped': {
        supervisord::supervisorctl { "stop_${name}":
          command => 'stop',
          process => $pname
        }
      }
      'removed': {
        supervisord::supervisorctl { "remove_${name}":
          command => 'remove',
          process => $pname
        }
      }
      'running': {
        supervisord::supervisorctl { "start_${name}":
          command => 'start',
          process => $pname,
          unless  => 'running'
        }
      }
      default: { }
    }
  }
}
