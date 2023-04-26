Name:           provii
Version:        0.3.1
Release:        1%{?dist}
Summary:        provii is a portable binary cli tool downloader

License:        GPLv3
URL:            https://github.com/kriipke/provii
Source:         %{name}-%{version}.tar.gz
BuildArch:      noarch

Requires:       bash, git, jq, unzip, tar

%description
The provii utility is a provisioning tool to painlessly download your favorite command-line utilities as pre-compiled binaries on a machine that that may be missing them. It is a convenient alternative when you do not have the premissions required to install software using the systems package manager or when you do not wish to install the software system-wide.

%prep
%setup -q

%install
rm -rf $RPM_BUILD_ROOT
mkdir -p $RPM_BUILD_ROOT/%{_bindir}
install %{name} $RPM_BUILD_ROOT/%{_bindir}
mkdir -p $RPM_BUILD_ROOT/%{_sysconfdir}
install %{name}rc $RPM_BUILD_ROOT/%{_sysconfdir}
mkdir -p $RPM_BUILD_ROOT/%{_mandir}/man1/
install %{name}.1 $RPM_BUILD_ROOT/%{_mandir}/man1/

%clean
rm -rf $RPM_BUILD_ROOT

%files
%{_bindir}/%{name}
%{_sysconfdir}/%{name}rc
%doc %{_mandir}/man1/%{name}.1.*
%license LICENSE

%changelog
* Wed Apr 26 2023 kriipke
- configured spec file for use with GitHub Actions to automate building of RPM

* Tue Apr 18 2023 kriipke
- initial release
