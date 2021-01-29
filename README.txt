

debsrv is a simple debian package server implented with busybox, apt and systemd.
Its scripted with nothing more than bash.



~DESCRIPTION OF REPOSITIORY MANAGEMENT UTILITIES~

Found at this location src/bin/.

Configuration for these utilities and others is largely based on contents of src/lib/config.sh

Usage may be discovered for each by invoking with -h,--help option.

 • deploy.sh
 Setup or teardown paths, systemd configuration.

 • list_section.sh
 Display any configured suite/component pairings.

 • add_section.sh
 Add a suite, component(s) to repository.

 • remove_section.sh
 Remove a suite, component(s) from repository.

 • list_pkg.sh
 Display package(s) found in archive and standby area.

 • ingest_pkg.sh
 Move package(s) from incoming path to archive.
 Packages failing ingest move to standby area.

 • egest_pkg.sh
 Remove package(s) from archive to standby area.

 • reindex.sh
 Rebuild cached indexes for specified area of archive.
 Use in case of modifications made outside of devsrv utilities,
 or in case of some failure.

 • logrotate.sh
 Rotate log(s) in log area.



~SERVER OVERVIEW~

debsrv uses the busybox httpd server.  Its pretty basic.

 BROWSABLE RESOURCES:
 • dists/
 Description of repository according to apt structure.

 • incoming/
 Package(s) awaiting ingestion, section specific.

 • pool/
 Package(s) found in archive area.

 • standby/
 Package(s) removed from archive or package(s) that failed ingestion.
 They are not deleted.

 • sources.list.d/
 Contents appropriate for apt sources.list file.
 One file per suite.

 • log/
 Primitive logging.  Mostly busybox output.

 • doc/
 A little extra information about how debsrv works.

 HTTP METHODS:
 • GET
 For every browsable resource.

 • POST
 Limited to ingest of incoming packages.



~EXAMPLE USAGE~

INSTALL:

 # GET SOURCE
 $ git clone https://github.com/ryanormous/debsrv.git

 # DEPLOY
 $ sudo ./debsrv/bin/deploy.sh

 # ADD KEY
 $ sudo apt-key add - <<<$(curl http://127.0.0.1:8888/gpg/debsrv.gpg)

1) EXAMPLE:

 # ADD SECTION TO ARCHIVE
 $ sudo /opt/debsrv/bin/add_section.sh test

 # ADD PACKAGE(S) TO INCOMING PATH
 $ sudo cp -v nada_1.0_all.deb /opt/debsrv/incoming/test/main/

 # INGEST PACKAGE(S)
 $ sudo /opt/debsrv/bin/ingest_pkg.sh test

 # ADD SOURCES LIST
 $ curl http://127.0.0.1:8888/sources.list.d/debsrv-test.list | sudo dd of=/etc/apt/sources.list.d/debsrv-test.list

 # UPDATE APT SOURCES
 $ apt-get update -o Dir::Etc::sourcelist=/etc/apt/sources.list.d

 # SIMULATE INSTALL FROM debsrv
 $ apt-get -s install nada

 # REMOVE PACKAGE
 $ sudo /opt/debsrv/bin/egest_pkg.sh test -c main -p nada_1.0_all.deb

2) EXAMPLE:

 # ADD SECTION TO ARCHIVE
 $ sudo /opt/debsrv/bin/add_section.sh test -c extra

 # UPDATE SOURCES LIST
 $ curl http://127.0.0.1:8888/sources.list.d/debsrv-test.list | sudo dd of=/etc/apt/sources.list.d/debsrv-test.list

 # RE-ADD PACKAGE(S) TO INCOMING PATH
 $ sudo mv -v /opt/debsrv/standby/test/main/nada_1.0_all.deb /opt/debsrv/incoming/test/extra/

 # INGEST PACKAGE(S) USING SERVER METHOD
 $ curl -X POST http://127.0.0.1:8888/incoming/test/extra/

UNINSTALL:

 $ sudo /opt/debsrv/bin/deploy.sh --uninstall



~LIBRARY OVERVIEW~

 • lib/config.sh
 Configuration for debsrv.

 • lib/debsrv.sh
 Library of debsrv functions.



~SYSTEMD UNITS~

 • debsrv.service
 HTTPD SERVICE

 • debsrv-job.service
 INGEST JOB SERVICE

 • debsrv-job.path
 INCOMING JOB SERVICE



~JOBS~

The debsrv job queue is simple and sequential.
debsrv can also ingest packages down to the
individual package.  Keep this in mind before
starting a large ingest job.

