# Arm GNU Toolchain Install

This script fetches available versions of the toolchain from [the download page](https://developer.arm.com/downloads/-/arm-gnu-toolchain-downloads), gets one of them and installs it as a Debian package.

```console
$ ./arm-gnu-toolchain-install.sh
Fetching... Done
[ 0] arm-gnu-toolchain-12.2.mpacbti-rel1-x86_64-arm-none-eabi
[ 1] arm-gnu-toolchain-12.2.rel1-x86_64-arm-none-eabi
[ 2] arm-gnu-toolchain-12.2.rel1-x86_64-arm-none-linux-gnueabihf
[ 3] arm-gnu-toolchain-12.2.rel1-x86_64-aarch64-none-elf
[ 4] arm-gnu-toolchain-12.2.rel1-x86_64-aarch64-none-linux-gnu
[ 5] arm-gnu-toolchain-12.2.rel1-x86_64-aarch64_be-none-linux-gnu
[ 6] arm-gnu-toolchain-12.2.mpacbti-bet1-x86_64-arm-none-eabi
[ 7] arm-gnu-toolchain-11.3.rel1-x86_64-arm-none-eabi
[ 8] arm-gnu-toolchain-11.3.rel1-x86_64-arm-none-linux-gnueabihf
[ 9] arm-gnu-toolchain-11.3.rel1-x86_64-aarch64-none-elf
[10] arm-gnu-toolchain-11.3.rel1-x86_64-aarch64-none-linux-gnu
[11] arm-gnu-toolchain-11.3.rel1-x86_64-aarch64_be-none-linux-gnu
Please select a package to install:
```

It's also possible to specify version and target patterns or configure the script for unattended installation (see below).

## Usage

You can simply clone the repo and run the script:

```bash
git clone https://github.com/mpekurin/arm-gnu-toolchain-install.git
cd arm-gnu-toolchain-install/
./arm-gnu-toolchain-install.sh [options...]
```

Or use the process substitution:

```bash
bash <(curl -s https://raw.githubusercontent.com/mpekurin/arm-gnu-toolchain-install/main/arm-gnu-toolchain-install.sh) [options...]
```

### Options

#### `-h`

Show help and exit.

#### `-v <pattern>`

Use the pattern to filter the suggested packages by their version. The default pattern is `\d+\.\d+\.\D+\d+` which matches any version.

E.g. using `-v .*rel\\d+` will make the script suggest only the release versions.

#### `-t <pattern>`

Use the pattern to filter the suggested packages by their target. The default pattern is `.*` which matches any target.

E.g. using `-t arm-none-eabi` will make the script suggest only the packages for arm-none-eabi targets.

#### `-l`

Install the latest version available. This is equal to selecting the package with an index of 0. Combined with `-v` and `-t`, this option is useful for unattended installation.

## Examples

```bash
# Suggest only the packages of version 12.2
./arm-gnu-toolchain-install.sh -v 12.2\\D.*
```

```bash
# Suggest only the packages available for arm-none-eabi targets
./arm-gnu-toolchain-install.sh -t arm-none-eabi
```

```bash
# Suggest only the packages of version 12.2 for arm-none-eabi targets
./arm-gnu-toolchain-install.sh -v 12.2\\D.* -t arm-none-eabi
```

```bash
# Install the latest release version available for arm-none-eabi targets
./arm-gnu-toolchain-install.sh -v .*rel\\d+ -t arm-none-eabi -l
```
