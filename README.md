# NixOS installation with Disko

Минимальный репозиторий для установки NixOS с **NixOS Minimal ISO**, **flakes** и **nix-community/disko**.

Конфигурация рассчитана на:

- архитектуру `x86_64-linux`;
- загрузку в режиме **UEFI**;
- один системный диск;
- таблицу разделов GPT;
- EFI System Partition 1 GiB;
- Btrfs-раздел на всё оставшееся место с подразделами `@root`, `@home`, `@nix`, `@log`;
- сжатие `zstd` для каждого подраздела;
- загрузчик systemd-boot;
- NetworkManager;
- OpenSSH;
- пользователя `nikolaev`.

> [!CAUTION]
> Установка с Disko **полностью удалит разметку и данные с выбранного диска**.
> Перед запуском обязательно несколько раз проверьте имя диска командой `lsblk`.

## Структура репозитория

```text
.
├── flake.nix
├── configuration.nix
├── hardware-configuration.nix
├── disko.nix
└── README.md
```

### Назначение файлов

- `flake.nix` — подключает Nixpkgs и Disko и объявляет конфигурацию `nixos`.
- `configuration.nix` — базовая конфигурация установленной системы.
- `hardware-configuration.nix` — универсальный минимальный набор модулей для SATA/NVMe/USB/virtio.
- `disko.nix` — декларативная разметка системного диска.
- `README.md` — инструкция по установке.

---

# 1. Скачать Minimal ISO

Скачайте **NixOS Minimal ISO x86_64** с официального сайта NixOS и запишите ISO на USB-накопитель.

Загрузите компьютер с USB в режиме **UEFI**.

Проверить режим загрузки:

```bash
test -d /sys/firmware/efi && echo "UEFI OK" || echo "Booted in Legacy BIOS mode"
```

Для этой конфигурации должно быть:

```text
UEFI OK
```

---

# 2. Подключить сеть

## Проводная сеть

Обычно DHCP поднимается автоматически.

Проверка:

```bash
ip addr
ping -c 3 github.com
```

## Wi-Fi

Посмотреть интерфейсы:

```bash
nmcli device
```

Список сетей:

```bash
nmcli device wifi list
```

Подключение:

```bash
nmcli device wifi connect "SSID" password "PASSWORD"
```

Проверка:

```bash
ping -c 3 github.com
```

---

# 3. Перейти в root

```bash
sudo -i
```

---

# 4. Проверить системный диск

Покажите диски:

```bash
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL
```

Также полезно:

```bash
ls -l /dev/disk/by-id/
```

Примеры системных дисков:

```text
/dev/sda
/dev/vda
/dev/nvme0n1
```

Не используйте имя раздела вроде:

```text
/dev/sda1
/dev/nvme0n1p1
```

Нужен именно **весь диск**.

## Важно

Следующая команда уничтожит текущую таблицу разделов и данные на указанном диске.

---

# 5. Клонировать репозиторий

В Minimal ISO уже можно использовать Git через `nix shell`, даже если `git` отсутствует в окружении.

```bash
cd /tmp
nix --extra-experimental-features "nix-command flakes" shell nixpkgs#git -c \
  git clone https://github.com/nikolaevmpf/nixos_install.git
cd nixos_install
```

Проверить файлы:

```bash
ls -la
```

---

# 6. Проверить flake

```bash
nix --extra-experimental-features "nix-command flakes" flake show
```

Должна быть доступна конфигурация:

```text
nixosConfigurations.nixos
```

При желании можно предварительно проверить вычисление конфигурации:

```bash
nix --extra-experimental-features "nix-command flakes" \
  build .#nixosConfigurations.nixos.config.system.build.toplevel --no-link
```

---

# 7. Установка через disko-install

Ниже приведён рекомендуемый вариант.

Disko принимает реальный системный диск через параметр:

```text
--disk main DEVICE
```

Поэтому менять `disko.nix` перед каждой установкой не требуется.

## SATA / SAS / виртуальный SCSI диск

Например, если системный диск:

```text
/dev/sda
```

запустите:

```bash
sudo nix --extra-experimental-features "nix-command flakes" \
  run github:nix-community/disko/latest#disko-install -- \
  --write-efi-boot-entries \
  --flake .#nixos \
  --disk main /dev/sda
```

## NVMe

Если системный диск:

```text
/dev/nvme0n1
```

используйте:

```bash
sudo nix --extra-experimental-features "nix-command flakes" \
  run github:nix-community/disko/latest#disko-install -- \
  --write-efi-boot-entries \
  --flake .#nixos \
  --disk main /dev/nvme0n1
```

## KVM / QEMU

Часто диск называется:

```text
/dev/vda
```

Тогда:

```bash
sudo nix --extra-experimental-features "nix-command flakes" \
  run github:nix-community/disko/latest#disko-install -- \
  --write-efi-boot-entries \
  --flake .#nixos \
  --disk main /dev/vda
```

### Что делает эта команда

`disko-install`:

1. вычисляет flake;
2. уничтожает существующую разметку выбранного диска;
3. создаёт GPT;
4. создаёт EFI-раздел;
5. создаёт Btrfs и подразделы для `/`, `/home`, `/nix`, `/var/log`;
6. монтирует файловые системы;
7. устанавливает NixOS;
8. устанавливает systemd-boot;
9. записывает UEFI boot entry.

---

# 8. Разметка диска

Файл `disko.nix` создаёт следующую схему:

```text
Disk
├── ESP    1 GiB   FAT32   /boot
└── root   rest    Btrfs
    ├── @root   /        compress=zstd,noatime
    ├── @home   /home    compress=zstd
    ├── @nix    /nix     compress=zstd,noatime
    └── @log    /var/log compress=zstd
```

Отдельные физические разделы для `/home`, `/nix` и `/var/log` не создаются: подразделы Btrfs используют общий объём свободного места. Снимки Btrfs автоматически не настроены; подразделы только дают возможность добавить их позже.

Swap-раздел и swap-файл не создаются. Гибернация в этой схеме не предусмотрена.

Вместо него включён:

```nix
zramSwap.enable = true;
```

---

# 9. Завершить установку

После успешного выполнения `disko-install`:

```bash
reboot
```

Извлеките установочный USB-накопитель.

---

# 10. Первый вход

По умолчанию создаётся пользователь:

```text
nikolaev
```

В шаблоне установлен временный пароль:

```text
nixos
```

> [!WARNING]
> Этот пароль предназначен только для первого входа.

Сразу после загрузки смените его:

```bash
passwd
```

---

# 11. Проверить установленную систему

После входа:

```bash
hostnamectl
lsblk -f
findmnt /
findmnt /boot
findmnt /home
findmnt /nix
findmnt /var/log
systemctl status NetworkManager
systemctl status sshd
```

Проверить поколение NixOS:

```bash
nixos-version
```

---

# 12. Где находится конфигурация после установки

Репозиторий, использованный из Live ISO, автоматически не становится каталогом `/etc/nixos`.

Для дальнейшего управления рекомендуется после первого входа снова клонировать репозиторий:

```bash
cd ~
git clone https://github.com/nikolaevmpf/nixos_install.git nixos-config
cd nixos-config
```

Проверить конфигурацию:

```bash
sudo nixos-rebuild build --flake .#nixos
```

Применить:

```bash
sudo nixos-rebuild switch --flake .#nixos
```

---

# 13. Обновление flake

Создать или обновить `flake.lock`:

```bash
nix flake update
```

Проверить изменения:

```bash
git status
git diff
```

После обновления рекомендуется сначала собрать конфигурацию:

```bash
sudo nixos-rebuild build --flake .#nixos
```

и только потом переключаться:

```bash
sudo nixos-rebuild switch --flake .#nixos
```

---

# 14. Установка напрямую из GitHub

Клонировать репозиторий необязательно.

После проверки системного диска можно установить прямо из GitHub.

Пример для `/dev/nvme0n1`:

```bash
sudo nix --extra-experimental-features "nix-command flakes" \
  run github:nix-community/disko/latest#disko-install -- \
  --write-efi-boot-entries \
  --flake github:nikolaevmpf/nixos_install#nixos \
  --disk main /dev/nvme0n1
```

Для первой установки всё же рекомендуется вариант с клонированием репозитория: так проще просмотреть конфигурацию перед уничтожением диска.

---

# 15. Почему используется disko-install

Для этого репозитория основной способ установки — `disko-install`.

В `disko.nix` намеренно указан безопасный placeholder:

```text
/dev/disk/by-id/REPLACE_ME
```

Реальный диск передаётся только в момент установки:

```text
--disk main /dev/...
```

Это позволяет использовать один и тот же репозиторий на машинах, где системный диск может называться `/dev/sda`, `/dev/vda` или `/dev/nvme0n1`.

Не запускайте обычный режим:

```bash
disko --flake .#nixos
```

пока в `disko.nix` остаётся `REPLACE_ME`.

Если понадобится двухэтапная схема «сначала разметить, затем отдельно выполнить nixos-install», сначала явно измените `device` в `disko.nix` на стабильный путь из `/dev/disk/by-id/`. Для стандартной установки это не требуется.

---

# 16. Изменение имени компьютера

Откройте:

```text
configuration.nix
```

и измените:

```nix
networking.hostName = "nixos";
```

После установки или на уже установленной системе:

```bash
sudo nixos-rebuild switch --flake .#nixos
```

---

# 17. Изменение имени пользователя

В `configuration.nix` измените блок:

```nix
users.users.nikolaev = {
  isNormalUser = true;
  description = "NixOS administrator";
  extraGroups = [ "networkmanager" "wheel" ];
  initialPassword = "nixos";
};
```

Также желательно изменить временный пароль перед публикацией собственного форка или после первого входа.

---

# 18. Если установка завершилась ошибкой

Посмотреть диски:

```bash
lsblk -f
```

Посмотреть монтирования:

```bash
mount | grep /mnt
```

UEFI:

```bash
ls /sys/firmware/efi
```

EFI variables:

```bash
efibootmgr -v
```

Если необходимо повторить установку, сначала убедитесь, что выбран именно правильный диск.

---

# 19. Важное замечание о hardware-configuration.nix

Обычная ручная установка NixOS часто использует файл, созданный командой:

```bash
nixos-generate-config
```

В этом репозитории разметка и файловые системы полностью описываются через Disko, поэтому UUID разделов в `hardware-configuration.nix` не нужны. После установки проверьте `findmnt -o TARGET,SOURCE,FSTYPE,OPTIONS / /home /nix /var/log /boot` и `lsblk -f`.

Файл `hardware-configuration.nix` содержит общий набор initrd-модулей для наиболее распространённых контроллеров:

- AHCI/SATA;
- NVMe;
- USB storage;
- virtio-blk;
- virtio-scsi;
- virtio-pci.

Для конкретного физического компьютера после успешной установки при необходимости можно создать аппаратно-специфичную конфигурацию и перенести нужные параметры в репозиторий.

---

# Полная короткая последовательность

Пример для NVMe:

```bash
sudo -i

lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL
ping -c 3 github.com

cd /tmp
nix --extra-experimental-features "nix-command flakes" shell nixpkgs#git -c \
  git clone https://github.com/nikolaevmpf/nixos_install.git

cd nixos_install

nix --extra-experimental-features "nix-command flakes" flake show

sudo nix --extra-experimental-features "nix-command flakes" \
  run github:nix-community/disko/latest#disko-install -- \
  --write-efi-boot-entries \
  --flake .#nixos \
  --disk main /dev/nvme0n1

reboot
```

Перед выполнением последней команды обязательно замените `/dev/nvme0n1` на фактический системный диск.
