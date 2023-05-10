%bcond_without tests
%bcond_without weak_deps

ROS_PACKAGE_NO_DEBUGINFO
%global __os_install_post %(echo '%{__os_install_post}' | sed -e 's!/usr/lib[^[:space:]]*/brp-python-bytecompile[[:space:]].*$!!g')
%global __provides_exclude_from ^/opt/ros/%{ros_distro}/.*$
%global __requires_exclude_from ^/opt/ros/%{ros_distro}/.*$

%define RosPkgName      ROS_PACKAGE_NAME

Name:           ros-%{ros_distro}-%{RosPkgName}
Version:        ROS_PACKAGE_VERSION
Release:        ROS_PACKAGE_RELEASE%{?dist}%{?release_suffix}
Summary:        ROS_PACKAGE_SUMMARY

Url:            ROS_PACKAGE_URL
License:        ROS_PACKAGE_LICENSE
Source0:        %{name}_%{version}.orig.tar.gz
ROS_SOURCE_FIX

ROS_PACKAGE_REQUIRES
ROS_ALL_FIX_REQUIRESRequires: ros-%{ros_distro}-ros-workspace

ROS_PACKAGE_BUILDREQUIRES
ROS_ALL_FIX_REQUIRESBuildRequires: ros-%{ros_distro}-ros-workspace

%if 0%{?with_tests}
ROS_TEST_BUILDREQUIRES
%endif

Provides:       %{name}-devel = %{version}-%{release}
Provides:       %{name}-doc = %{version}-%{release}
Provides:       %{name}-runtime = %{version}-%{release}
ROS_PROVIDES_FIX

%description
ROS_PACKAGE_DESCRIPTION

%prep
%autosetup -p1
ROS_PREP_FIX

%build
# Needed to bootstrap since the ros_workspace package does not yet exist.
export PYTHONPATH=/opt/ros/%{ros_distro}/lib/python%{python3_version}/site-packages

# In case we're installing to a non-standard location, look for a setup.sh
# in the install tree and source it.  It will set things like
# CMAKE_PREFIX_PATH, PKG_CONFIG_PATH, and PYTHONPATH.
if [ -f "/opt/ros/%{ros_distro}/setup.sh" ]; then . "/opt/ros/%{ros_distro}/setup.sh"; fi
mkdir -p .obj-%{_target_platform} && cd .obj-%{_target_platform}
%cmake3 \
    -UINCLUDE_INSTALL_DIR \
    -ULIB_INSTALL_DIR \
    -USYSCONF_INSTALL_DIR \
    -USHARE_INSTALL_PREFIX \
    -ULIB_SUFFIX \
    -DCMAKE_INSTALL_PREFIX="/opt/ros/%{ros_distro}" \
    -DAMENT_PREFIX_PATH="/opt/ros/%{ros_distro}" \
    -DCMAKE_PREFIX_PATH="/opt/ros/%{ros_distro}" \
    -DSETUPTOOLS_DEB_LAYOUT=OFF \
%if !0%{?with_tests}
    -DBUILD_TESTING=OFF \
%endif
    ..

%make_build

%install
# Needed to bootstrap since the ros_workspace package does not yet exist.
export PYTHONPATH=/opt/ros/%{ros_distro}/lib/python%{python3_version}/site-packages

# In case we're installing to a non-standard location, look for a setup.sh
# in the install tree and source it.  It will set things like
# CMAKE_PREFIX_PATH, PKG_CONFIG_PATH, and PYTHONPATH.
if [ -f "/opt/ros/%{ros_distro}/setup.sh" ]; then . "/opt/ros/%{ros_distro}/setup.sh"; fi
%make_install -C .obj-%{_target_platform}

%if 0%{?with_tests}
%check
# Needed to bootstrap since the ros_workspace package does not yet exist.
export PYTHONPATH=/opt/ros/%{ros_distro}/lib/python%{python3_version}/site-packages

# Look for a Makefile target with a name indicating that it runs tests
TEST_TARGET=$(%__make -qp -C .obj-%{_target_platform} | sed "s/^\(test\|check\):.*/\\1/;t f;d;:f;q0")
if [ -n "$TEST_TARGET" ]; then
# In case we're installing to a non-standard location, look for a setup.sh
# in the install tree and source it.  It will set things like
# CMAKE_PREFIX_PATH, PKG_CONFIG_PATH, and PYTHONPATH.
if [ -f "/opt/ros/%{ros_distro}/setup.sh" ]; then . "/opt/ros/%{ros_distro}/setup.sh"; fi
CTEST_OUTPUT_ON_FAILURE=1 \
    %make_build -C .obj-%{_target_platform} $TEST_TARGET || echo "RPM TESTS FAILED"
else echo "RPM TESTS SKIPPED"; fi
%endif

%files
/opt/ros/%{ros_distro}

%changelog
* ROS_PACKAGE_CHANGELOG
- Autogenerated by ros-porting-tools
