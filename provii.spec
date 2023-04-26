Name:           provii
Version:        0.1.0
Release:        1%{?dist}
Summary:        provii is a portable binary cli tool downloader.

License:        GPL 
URL:            https://github.com/kriipke/provii
Source0:        %{name}-%{version}.tar.gz

Requires:       bash, git, jq, unzip, tar

%description
The provii utility is a provisioning tool to painlessly download your favorite command-line utilities as pre-compiled binaries on a machine that that may be missing them. It is a convenient alternative when you do not have the premissions required to install software using the systems package manager or when you do not wish to install the software system-wide.

%prep
gzip ${name}.1

%setup -q

%install
rm -rf $RPM_BUILD_ROOT
mkdir -p $RPM_BUILD_ROOT/%{_bindir}
cp %{name} $RPM_BUILD_ROOT/%{_bindir}
mkdir -p $RPM_BUILD_ROOT/%{_sysconfdir}
cp %{name}rc $RPM_BUILD_ROOT/%{_sysconfdir}
mkdir -p $RPM_BUILD_ROOT/%{_mandir}/man1/
cp %{name}.1.* $RPM_BUILD_ROOT/%{_mandir}/man1/

%files
%{_bindir}/%{name}
%{_sysconfdir}/proviirc.example
%doc %{_mandir}/man1/%{name}.1.*
%license LICENSE

%changelog
* Tue Apr 18 2023 kriipke
- initial release
