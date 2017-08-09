Name:      automated-extras
Version:   %{rpm_version}
Release:   %{rpm_release}
Summary:   Extra functions for the automated.sh
URL:       https://github.com/node13h/automated-extras
License:   GPLv3+
BuildArch: noarch
Source0:   automated-extras-%{full_version}.tar.gz

%description
A collection of useful scripts and functions for the automated.sh tool

%prep
%setup -n automated-extras-%{full_version}

%clean
rm -rf --one-file-system --preserve-root -- "%{buildroot}"

%install
make install DESTDIR="%{buildroot}" PREFIX="%{prefix}"

%files
%{_bindir}/*
%{_libdir}/*
%{_defaultdocdir}/*
