#!/bin/bash
###############################################################################
#
# Update debian repository indexes
#
# It actually makes maven repositories expose a debian index.
#
# It also create a "virtual" stable debian repository in which is selected only
# stable releases (filter milestonnes and release candidates).
# It also create a "virtual" lts debian repository in which is selected only
# configured lts branch releases.
#
# Requirements:
# * This script is based on scna_packages. It is provided by dpkg-dev.
# * The script expect to find
# ** a "releases" folder containing a maven repository with the deployed
#    releases
# ** a "snapshots" dolder containing a maven repository with the deployed
#    snaphots
# ** make sure the "stable" folder exists if you want a filtered stable debian
#    repository
# ** make sure the "lts" folder exists if you want a filtered lts debian
#    repository. Also make sure you configured the lts branch version
#
# Setup:
# You need to set the $ROOT_REP variable to where your maven repositories are
# located.
#
###############################################################################

ROOT_REP=/home/maven/public_html
SNAPSHOTS_REP="snapshots"
RELEASES_REP="releases"
STABLE_REP="stable"
LTS_REP="lts"
LTS_BRANCH="15.10"
RECOMMENDED_REP="recommended"
RECOMMENDED_BRANCH="16.4"
GPG_KEY="93CC9C13"

cd "$ROOT_REP"

function link_package ()
{
  local package=$1
  local repositoryName=$2

  local basepath=`dirname $package`
  local basepath=${basepath##$ROOT_REP/}
  local basepath=${basepath%*/}
  mkdir -p $basepath
  local fullpath=`readlink -f $package`
  ln -sf $fullpath "/tmp/${repositoryName}_scanpackages/$basepath"
}

function link_packages ()
{
  local pattern=$1
  local repositoryName=$2

  for i in $(find $ROOT_REP/$RELEASES_REP/org/xwiki/**/*debian* -regex $pattern ) ; do
    link_package $i $repositoryName
  done
}

function update_repository ()
{
  local repositoryName=$1
  local repositoryPattern=$2

  if [ -d $repositoryName ]; then
    echo "Generates $repositoryName index"

    rm -rf /tmp/${repositoryName}_scanpackages
    mkdir -p /tmp/${repositoryName}_scanpackages/$RELEASES_REP

    cd /tmp/${repositoryName}_scanpackages/

    link_packages $repositoryPattern $repositoryName

    dpkg-scanpackages -m $RELEASES_REP /dev/null > "$ROOT_REP/$repositoryName/Packages.tmp" && mv -f "$ROOT_REP/$repositoryName/Packages.tmp" "$ROOT_REP/$repositoryName/Packages"
    gzip -9c "$ROOT_REP/$repositoryName/Packages" > "$ROOT_REP/$repositoryName/Packages.gz.tmp" && mv -f "$ROOT_REP/$repositoryName/Packages.gz.tmp" "$ROOT_REP/$repositoryName/Packages.gz"

    cd "$ROOT_REP"

    rm -rf $repositoryName/Release $repositoryName/Release.gpg
    apt-ftparchive -c=$repositoryName/Release.conf release $repositoryName > $repositoryName/Release
    gpg --digest-algo SHA512 -abs --default-key $GPG_KEY -o $repositoryName/Release.gpg $repositoryName/Release
  fi
}

## LTS
update_repository $LTS_REP ".*-${LTS_BRANCH}\(\.[0-9]+\)*\(-[0-9]+\)*.deb"

## stable
update_repository $STABLE_REP ".*\.[0-9]+\(-[0-9]+\)*.deb"

## recommended
update_repository $RECOMMENDED_REP ".*-${RECOMMENDED_BRANCH}\(\.[0-9]+\)*\(-[0-9]+\)*.deb"

## releases
if [ -d $RELEASES_REP ]; then
  echo "Generates releases index"

  dpkg-scanpackages -m $RELEASES_REP/org /dev/null > $RELEASES_REP/Packages.tmp && chmod 644 $RELEASES_REP/Packages.tmp && mv -f $RELEASES_REP/Packages.tmp $RELEASES_REP/Packages
  gzip -9c $RELEASES_REP/Packages > $RELEASES_REP/Packages.gz.tmp && chmod 644 $RELEASES_REP/Packages.gz.tmp && mv -f $RELEASES_REP/Packages.gz.tmp $RELEASES_REP/Packages.gz

  rm -rf $RELEASES_REP/Release $RELEASES_REP/Release.gpg
  apt-ftparchive -c=$RELEASES_REP/Release.conf release $RELEASES_REP > $RELEASES_REP/Release
  chmod 644 $RELEASES_REP/Release
  gpg --digest-algo SHA512 -abs --default-key $GPG_KEY -o $RELEASES_REP/Release.gpg $RELEASES_REP/Release
  chmod 644 $RELEASES_REP/Release.gpg
fi

## snapshots
# Unusable yet: see https://jira.xwiki.org/browse/XE-1090
#if [ -d $SNAPSHOTS_REP ]; then
#  echo "Generates snapshots index"
#
#  dpkg-scanpackages -m $SNAPSHOTS_REP /dev/null > $SNAPSHOTS_REP/Packages.tmp && mv -f $SNAPSHOTS_REP/Packages.tmp $SNAPSHOTS_REP/Packages
#  gzip -9c $SNAPSHOTS_REP/Packages > $SNAPSHOTS_REP/Packages.gz.tmp && mv -f $SNAPSHOTS_REP/Packages.gz.tmp $SNAPSHOTS_REP/Packages.gz
#fi
