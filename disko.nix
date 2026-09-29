{ ... }:

{
  disko.devices = {
    disk = {
      main = {
        type = "disk";

        # Placeholder only.
        # During installation pass the real disk explicitly:
        #
        #   --disk main /dev/sda
        #   --disk main /dev/nvme0n1
        #
        # disko-install overrides this value from the command line.
        device = "/dev/disk/by-id/REPLACE_ME";

        content = {
          type = "gpt";

          partitions = {
            ESP = {
              size = "1G";
              type = "EF00";

              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [
                  "umask=0077"
                ];
              };
            };

            root = {
              size = "100%";

              content = {
                type = "btrfs";
                extraArgs = [ "-f" ];
                subvolumes = {
                  "/@root" = {
                    mountpoint = "/";
                    mountOptions = [ "compress=zstd" "noatime" ];
                  };
                  "/@home" = {
                    mountpoint = "/home";
                    mountOptions = [ "compress=zstd" ];
                  };
                  "/@nix" = {
                    mountpoint = "/nix";
                    mountOptions = [ "compress=zstd" "noatime" ];
                  };
                  "/@log" = {
                    mountpoint = "/var/log";
                    mountOptions = [ "compress=zstd" ];
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}
