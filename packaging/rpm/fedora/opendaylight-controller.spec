Name: opendaylight-controller
# todo: Use the ODL snapshot version? Could also be used for the
# Source property in a proper URL.
Version: 0.1.0
Release: 0.1.20131101git31c8f18%{?dist}
Summary: OpenDaylight SDN Controller
Group: Applications/Communications
License: EPL
URL: http://www.opendaylight.org

# todo: Temporary method for generating tarball
# git clone https://git.opendaylight.org/gerrit/p/controller.git
# cd controller
# git archive --prefix=opendaylight-controller-0.1.0/ 31c8f18 | xz > opendaylight-controller-0.1.0.tar.xz
Source: opendaylight-controller-%{version}.tar.xz

BuildArch: noarch

BuildRequires: java-devel
BuildRequires: maven

Requires: java >= 1:1.7.0

# todo: Need to create proper packages for all the dependencies.
# Here you should have at least dependencies for the packages containing .jar
# files that you want to create symlinks to. For now all the jars in a
# dependencies package.
#Requires: slf4j
Requires: opendaylight-controller-dependencies

# This is the directory where all the application resources (scripts,
# libraries, etc) will be installed: /usr/share/opendaylight
%global resources_dir %{_datadir}/%{name}

# This is the directory where variable data used by the application should be
# created: /var/lib/opendaylight
%global data_dir %{_localstatedir}/lib/%{name}

# This is the directory where the application stores its configuration:
# /etc/opendaylight
%global configuration_dir %{_sysconfdir}/%{name}

%global deps_dir %{_javadir}/opendaylight-controller-dependencies


%description
OpenDaylight SDN Controller


%prep

# Just unpack the source code:
%setup -q

# In more restrictive distributions we should also here remove from the source
# package any third party binaries, or replace them with those provided by the
# distribution, before performing the actual build.


%build

# This regular maven build will need to be replaced by the distribution
# specific maven build command, but this is ok for now:
# todo: eventually move to using mvn-build or mvn-rpmbuild so dependencies are
# not downloaded.
MAVEN_OPTS="-Xmx1024m -XX:MaxPermSize=256m" && mvn clean install -DskipTests
#MAVEN_OPTS="-XX:PermSize=256m -Xmx1024m  -XX:MaxPermSize=512m" && mvn -DskipTests clean install
# below is just for testing
# MAVEN_OPTS="-Xmx1024m -XX:MaxPermSize=256m"; mvn package


%install

# Extract the contents of the distribution to a temporary directory so that we
# can take things from there and move them to the correct locations:
mkdir -p tmp
#unzip -o -d tmp opendaylight/distribution/opendaylight/target/distribution.opendaylight-%%{version}-SNAPSHOT-osgipackage.zip
unzip -o -d tmp opendaylight/distribution/opendaylight/target/distribution.opendaylight-osgipackage.zip

# Create the directories:
mkdir -p %{buildroot}%{configuration_dir}
mkdir -p %{buildroot}%{resources_dir}/configuration
mkdir -p %{buildroot}%{data_dir}/configuration

mv tmp/opendaylight/configuration/config.ini %{buildroot}%{configuration_dir}
ln -s %{configuration_dir}/config.ini %{buildroot}%{data_dir}/configuration
mv tmp/opendaylight/configuration/* %{buildroot}%{resources_dir}/configuration
rmdir tmp/opendaylight/configuration
ln -s %{resources_dir}/configuration/context.xml %{buildroot}%{data_dir}/configuration
ln -s %{resources_dir}/configuration/logback.xml %{buildroot}%{data_dir}/configuration
ln -s %{resources_dir}/configuration/tomcat-server.xml %{buildroot}%{data_dir}/configuration

mv tmp/opendaylight/* %{buildroot}%{resources_dir}

ln -s %{resources_dir}/lib %{buildroot}%{data_dir}
ln -s %{resources_dir}/plugins %{buildroot}%{data_dir}


# Usually one wants to replace the .jar files of the dependencies by symlinks
# to the ones provided to the system. This assumes the dependencies have been
# installed as separate packages and listed in the Requires header.
#while read resource_path system_path
#do
#    rm -f %%{buildroot}%%{resources_dir}/${resource_path}
##    ln -s %%{_javadir}/${system_path} %%{buildroot}%%{resources_dir}/${resource_path}
#    ln -s %%{deps_dir}/%%{system_path} %%{buildroot}%%{resources_dir}/${resource_path}
#done <<.
#lib/jersey-core.jar jersey-core.jar
#.
cd %{buildroot}%{resources_dir}/lib
for src in $( ls -I "org.opendaylight.*" );
do
    rm -f ${src}
    tgt=$(echo ${src} | sed -e "s/-[0-9].*/.jar/")
    ln -s %{deps_dir}/${tgt} ${src}
done

cd %{buildroot}%{resources_dir}/plugins
for src in $( ls -I "org.opendaylight.*" );
do
    rm -f ${src}
    tgt=$(echo ${src} | sed -e "s/-[0-9].*/.jar/")
    ln -s %{deps_dir}/${tgt} ${src}
done


# Fix the permissions as they come with all the permissions (mode 777)
# from the .zip file:
chmod -R 755 %{buildroot}%{resources_dir}

# Remove the temporary directory:
rm -rf tmp

# todo: Create systemd scripts to invoke run.sh. Might need to modify run.sh or
# create a different script to be used. RHEL will definitely need changes or a
# new script since it must take inputs such as "start" and "enable".


%pre

# todo: register the opendaylight group:user.
# Create the group and user that will run the service before installing the
# package, as some of the files and directories will be owned by this user:
getent group opendaylight > /dev/null
if [ "$?" != 0 ]; then
    groupadd \
        -f \
        -r \
        opendaylight
fi

getent passwd opendaylight > /dev/null
if [ "$?" != 0 ]; then
    useradd \
        -r \
        -g opendaylight \
        -c "OpenDaylight SDN" \
        -s /sbin/nologin \
        -d %{data_dir} \
        opendaylight
fi


%files

# Everything inside the resources directory:
%{resources_dir}

# Configuration files should marked as such, so that they aren't overwritten
# when updating the package:
%dir %{configuration_dir}
%config(noreplace) %{configuration_dir}/config.ini

# The data directory needs to be owned by the user that will run the service,
# as it will need to write inside:
%attr(-, opendaylight, opendaylight) %{data_dir}

# Documentation:
%doc LICENSE
%doc NOTICE
%doc README.OPENDAYLIGHT


# todo: add checks to ensure controller is stopped
#%%preun


%changelog
* Fri Nov 01 2013 Sam Hague <shague@redhat.com> - 0.1.0-0.1.20131007git31c8f18
- Modify to include opendaylight-controller-dependencies.
- Do not delete the files in var

* Mon Oct 07 2013 Sam Hague <shague@redhat.com> - 0.1.0-0.1.20131007gitd684dd4
- Initial Fedora package.
