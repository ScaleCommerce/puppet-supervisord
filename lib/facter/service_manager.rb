# Reports which process supervisor runs this node, so Puppet can dispatch
# supervisord::program to the right backend WITHOUT an explicit
# sc::service_manager hiera key. The catalog compiles on the server, so the
# only way the server learns the node's backend is a fact the node reports;
# this is that fact.
#
# Returns 'zpinit' when zpinit is the node's supervisor, else 'supervisor'.
# Any one of three ground-truth signals marks a zpinit node (the ScaleCommerce
# zpinit image bakes all three, so detection is reliable even on the first
# Puppet run before any service is up):
#   - /usr/local/bin/zpinit exists  (binary baked into the image)
#   - /run/zpinit.sock is a socket  (zpinit is running, control socket bound)
#   - PID 1 is zpinit               (zpinit is the container's supervisor)
# sc::service_manager remains available as an explicit override in hiera; this
# fact only supplies the default when that key is unset.
Facter.add(:service_manager) do
  setcode do
    is_zpinit =
      File.exist?('/usr/local/bin/zpinit') ||
      File.socket?('/run/zpinit.sock') ||
      (File.readable?('/proc/1/comm') && File.read('/proc/1/comm').strip == 'zpinit')
    is_zpinit ? 'zpinit' : 'supervisor'
  end
end
