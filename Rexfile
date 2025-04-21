use strict;
use warnings;

use Rex -feature => ['1.4'];
use Rex::Commands::Pkg;
use Rex::Commands::File;
use Rex::Commands::Fs;
use Rex::Commands::Run;

user "root";

my @hosts;
open( my $fh, "<", "hosts" ) or die "can't open hosts file: $!\n";
while (<$fh>) {
    chomp;
    push @hosts, $_;
}
close $fh;

group all => @hosts;

my $retic_home = "/home/reticulum";
my $venv_path  = "$retic_home/venv";

sub makeServiceFile {
    my ( $name, $desc, $args ) = @_;
    $args = "" unless $args;
    return "
[Unit]
Description=$desc
After=network.target

[Service]
Type=simple
User=reticulum
Group=reticulum
WorkingDirectory=$retic_home
Environment=PATH=$venv_path/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ExecStart=$venv_path/bin/$name $args
Restart=always

[Install]
WantedBy=multi-user.target
"
}

desc "Update system";
task "update",
  group => "all",
  sub {
    update_system,
      update_metadata => 1,
      update_package  => 1,
      dist_upgrade    => 1;
  };

desc "Setup Reticulum environment and service";
task "setup",
  group => "all",
  sub {
    # Create reticulum user
    create_group "reticulum", system => 1;
    create_user "reticulum",
      home        => $retic_home,
      group       => "reticulum",
      groups      => [ "dialout", "video" ],
      create_home => TRUE;

    # Install required packages
    pkg [qw(python3-venv git tmux picocom)], ensure => "latest";

    if ( !is_dir($venv_path) ) {
        run "python3 -m venv $venv_path";
    }

    run "$venv_path/bin/pip install --upgrade rns nomadnet rnsh",
      path => "$venv_path/bin";

    file "/etc/systemd/system/rnsd.service",
      owner   => "root",
      group   => "root",
      mode    => 644,
      content => makeServiceFile( "rnsd", "Reticulum Network Stack Daemon" );

    file "/etc/systemd/system/nomadnet.service",
      owner   => "root",
      group   => "root",
      mode    => 644,
      content => makeServiceFile( "nomadnet", "Nomadnet", "--daemon" );

    file "/etc/systemd/system/lxmd.service",
      owner   => "root",
      group   => "root",
      mode    => 644,
      content => makeServiceFile( "lxmd", "LXMD" );

    # Enable and start the service
    # service "rnsd",
    #     ensure => "started",
    #     enable => TRUE;

    service "nomadnet",
      ensure => "started",
      enable => TRUE;

    # service "lxmd",
    #     ensure => "started",
    #     enable => TRUE;

    # Set proper ownership
    run "chown -R reticulum:reticulum $venv_path";
  };
