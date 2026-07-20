df -h /tmp; free -h

  Sysctl som faktiskt hjälper:

  vm.swappiness=100              # swappa hellre än att kasta cache (med zram)
  vm.vfs_cache_pressure=200      # återta dentry/inode-cache snabbare
  vm.dirty_background_ratio=5    # börja skriva ut smutsiga sidor tidigare
  vm.dirty_ratio=10              # tak innan skrivningar blockerar
  vm.min_free_kbytes=65536       # reserv så allokeringar inte failar

  Sätt tillfälligt:
  sudo sysctl -w vm.swappiness=100 vm.vfs_cache_pressure=200
  Permanent i /etc/sysctl.d/99-mem.conf.
