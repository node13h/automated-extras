# automated-extras
A collection of useful scripts and functions for the automated.sh tool. Some of the code may eventually end up in the automated.sh standard library.

Most of the functions have only been tested on CentOS7 only and might not work on other systems.

# Example

example.sh:
```bash
set -euo pipefail

if [[ -n "${BASH_SOURCE[0]:-}" && "${0}" = "${BASH_SOURCE[0]}" ]]; then
    source automated-extras-config.sh

    exec automated.sh \
         --sudo \
         --load "${AUTOMATED_EXTRAS_LIBDIR}" \
         --load "${BASH_SOURCE[0]}" \
         "$@"
fi

main () {
    supported_automated_extras_versions 0.1

    pg_user_exists testuser || pg_createser testuser secret
}
```

Ensure the `testuser` PostgreSQL user exists on both `machine1.example.com` and `machine2.example.com`:
```bash
bash example.sh machine1.example.com machine2.example.com
```


## Installing

### From source

```bash
sudo make install
```

### Packages for RedHat-based systems

```bash
cat <<"EOF" | sudo tee /etc/yum.repos.d/alikov.repo
[alikov]
name=alikov
baseurl=https://dl.bintray.com/alikov/rpm
gpgcheck=0
repo_gpgcheck=1
gpgkey=https://bintray.com/user/downloadSubjectPublicKey?username=bintray
enabled=1
EOF

sudo yum install automated-extras
```

### Packages for Debian-based systems

```bash
curl 'https://bintray.com/user/downloadSubjectPublicKey?username=bintray' | sudo apt-key add -

cat <<"EOF" | sudo tee /etc/apt/sources.list.d/alikov.list
deb https://dl.bintray.com/alikov/deb xenial main
EOF

sudo apt-get update && sudo apt-get install automated-extras
```
