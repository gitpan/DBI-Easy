#!/usr/bin/perl -I../../../perl-easy/lib

use DBI;

use strict;

use Data::Dumper;

use Test::More qw(no_plan);

BEGIN {

	$Class::Easy::DEBUG = 'immediately';
	
	use_ok 'DBI::Easy';
	
	push @INC, 't', 't/DBI-Easy';
	require 'db-config.pl';
	
	my $dbh = &init_db;
	
	DBI::Easy->dbh ($dbh);

};

use Class::Easy;

use DBI::Easy::Test::Address;
use DBI::Easy::Test::Contact;
use DBI::Easy::Test::Passport;

use DBI::Easy::Test::Contact::Collection;

use DBI::Easy::Test::Account;
	

my $t = timer ('effective work: new');

my $account = DBI::Easy::Test::Account->new (
	{name => 'apla', meta => 'metainfo', pass => 'dsfasdfasdf'}
);

$t->lap ('insert');

$account->create;

$t->end;

ok $account;

my $dumped_fields = $account->TO_JSON;

ok scalar keys %$dumped_fields == 3;

&finish_db;

1;
