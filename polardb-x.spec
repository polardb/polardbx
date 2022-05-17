%undefine __brp_ldconfig
%undefine __brp_mangle_shebangs
%undefine __brp_strip_static_archive

Name:           polardb-x
Version:        2.1.0
Release:        2%{?dist}
Summary:        A MySQL compatiable distributed SQL database

License:        GPLv2,Apache License 2.0
URL:            https://doc.polardbx.com/
Source0:        https://github.com/apsaradb/%{name}/release/%{name}-%{version}.tar.gz

BuildRequires:  maven,java,cmake3,automake,bison,gcc
Requires:       bash,java >= 1.8 
Requires:	openssl >= 1:1.0.2a, glibc >= 2.14, ncurses >= 5.9, libaio >= 0.3.109, libtirpc >= 0.2.4
AutoReqProv:	no

%description
PolarDB-X is a cloud native distributed SQL Database designed for high concurrency, massive storage and complex querying scenarios. It has a shared-nothing architecture in which computing is decoupled from storage. It supports horizontal scaling, distributed transactions and Hybrid Transactional and Analytical Processing (HTAP) workloads, and is characterized by enterprise-class, cloud native, high availability, highly compatible with MySQL and its ecosystem.

%global debug_package %{nil}
%global __strip %{_bindir}/strip

%prep
%autosetup


%build
make %{?_smp_mflags}

%install
make DESTDIR=/home/admin/polardb-x install
rm -rf %{buildroot}
mkdir -p %{buildroot}/home/admin
rm -rf /home/admin/polardb-x/galaxyengine/u01/mysql/mysql-test
mv /home/admin/polardb-x %{buildroot}/home/admin/

%files
%license README.md
/home/admin/polardb-x


%changelog
* Thu Jan  6 2022 free6om <xueqiang.wxq@alibaba-inc.com> - 0.5.0-1
- First release of PolarDB-X CE
