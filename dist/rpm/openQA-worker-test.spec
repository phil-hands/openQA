%define         short_name openQA-worker
Name:           %{short_name}-test
Version:        4.6
Release:        0
Summary:        Test package for %{short_name}
License:        GPL-2.0-or-later
BuildRequires:  %{short_name} == %{version}
ExcludeArch:    i586

%description
.

%prep
# workaround to prevent post/install failing assuming this file for whatever
# reason
touch %{_sourcedir}/%{short_name}

%build
/usr/share/openqa/script/worker --help

%install
# disable debug packages in package test to prevent error about missing files
%define debug_package %{nil}

%changelog
