# Spec file only supports RHEL and Fedora now
%if 0%{?rhel} || 0%{?fedora}

Name: opendaylight-vtn
Version: 0.1.0
Release: 0.1.0%{?dist}
Summary: OpenDaylight VTN
Group: Applications/Communications
License: EPL
URL: http://www.opendaylight.org

# todo: Temporary method for generating tarball
# git clone https://git.opendaylight.org/gerrit/p/vtn.git
# cd vtn
# git archive --prefix=opendaylight-vtn-0.1.0/ HEAD | xz > opendaylight-vtn-0.1.0.tar.xz
Source0: %{name}-%{version}.tar.xz

BuildArch: noarch

BuildRequires: java-devel
BuildRequires: maven
Requires: java >= 1:1.7.0

# This is the directory where all the application resources (scripts,
# libraries, etc) will be installed: /usr/share/opendaylight
%global resources_dir %{_datadir}/opendaylight-controller

# This is the directory that has all the JAVA dependencies.
%global deps_dir %{_javadir}/opendaylight-controller-dependencies


%description
OpenDaylight VTN


%prep

%setup -q


%build

# This regular maven build will need to be replaced by the distribution
# specific maven build command, but this is ok for now:
# todo: eventually move to using mvn-build or mvn-rpmbuild so dependencies are
# not downloaded.
# Don't do the tests since those are already covered by the normal merge and
# verify process and this build does not need to verify them.
# maven.compile.fork is used to reduce the build time.
#export MAVEN_OPTS="-Xmx1024m -XX:MaxPermSize=256m" && \
#  mvn clean install -Dmaven.test.skip=true -DskipIT -Dmaven.compile.fork=true
export MAVEN_OPTS="-Xmx1024m -XX:MaxPermSize=256m" && mvn clean install -Dmaven.test.skip=true

%install

# Extract the contents of the distribution to a temporary directory so that we
# can take things from there and move them to the correct locations:
# todo: Need spec and pom file versions to be consistent so we don't have to
# hardcode the version here.
mkdir -p tmp
unzip -o -d tmp manager/dist/target/distribution.vtn-manager-0.1.0-SNAPSHOT-osgipackage.zip

# Create the directories:
mkdir -p %{buildroot}%{resources_dir}/plugins

# Only install the extra jars needed by vtn.
# opendaylight jars will be moved to the plugins dir and external jars will be
# symlinked to the opendaylight dependencies directory.
for src in $( ls tmp/opendaylight/plugins/*.jar);
do
    tgt=$(basename ${src})
    if [ ! -f %{_builddir}/%{buildsubdir}/manager/dist/target/generated-resources/opendaylight/plugins/${tgt} ]; then
        if [ "${tgt}" != "${tgt/org.opendaylight/}" ]; then
            mv ${src} %{buildroot}%{resources_dir}/plugins
        else
            ln -s %{deps_dir}/${tgt} %{buildroot}%{resources_dir}/plugins/${tgt}
        fi
    fi
done

# Create the directories for VTN coordinator
mkdir -p %{buildroot}%{resources_dir}/externalapps

#VTN coordinator has tar.bz2 as external apps
for src in $( ls %{_builddir}/%{buildsubdir}/coordinator/dist/target/*.tar.bz2);
do
    tgt=org.opendaylight.vtn.$(basename ${src})
    mv ${src} %{buildroot}%{resources_dir}/externalapps/${tgt}
done


# Fix the permissions as they come with all the permissions (mode 777)
# from the .zip file:
find %{buildroot}%{resources_dir} -type d -exec chmod 755 {} \;
find %{buildroot}%{resources_dir} -type f -exec chmod 644 {} \;

# Remove the temporary directory:
rm -rf tmp


%clean
%if "%{noclean}" == "1"
    exit 0
%endif


%files

%{resources_dir}


%endif

%changelog
* Tue Jan 07 2014 Hsin-Yi Shen <hshen@redhat.com> - 0.1.0-0.1.0
- Initial package.
