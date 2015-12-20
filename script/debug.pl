#!/usr/bin/perl

use strict;
use warnings;


use FindBin qw($Bin);
use lib "$Bin/../lib/";

use WebApp::Suica;
use Data::Dumper;

my $filename = shift;

my $db = WebApp::Suica->new(filename => $filename);

$db->register_csv2db;

$db->show_all_db;

$db->check_id;

$db->{'dbh'}->disconnect;

