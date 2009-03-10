#!/usr/bin/perl -I../../../perl-easy/lib

use DBI;

use strict;

use Data::Dumper;

use Test::More qw(no_plan);

BEGIN {

	use_ok 'DBI::Easy';
	
	push @INC, 't', 't/DBI-Easy';
	require 'db-config.pl';
	
	my $dbh = &init_db;
	
	DBI::Easy->dbh ($dbh);
	
	use_ok 'DBI::Easy::Test::Account';
};

my $account = DBI::Easy::Test::Account->new (
	{name => 'apla', meta => 'metainfo', pass => 'dsfasdfasdf'}
);

$account->create;

ok $account;

my $dumped_fields = $account->TO_JSON;



ok scalar keys %$dumped_fields == 3;

1;