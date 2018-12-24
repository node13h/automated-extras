Name:      automated-extras
Version:   %{rpm_version}
Release:   %{rpm_release}
Summary:   Extra functions for automated.sh
URL:       https://github.com/node13h/automated-extras
License:   MIT
BuildArch: noarch
Source0:   %{sdist_tarball}

%description
A collection of useful scripts and functions for the automated.sh tool

%prep
%setup -n %{sdist_dir}

%clean
rm -rf --one-file-system --preserve-root -- "%{buildroot}"

%install
make install DESTDIR="%{buildroot}" PREFIX="%{prefix}"

%files
%{_bindir}/*
%{_libdir}/*
%{_defaultdocdir}/*
