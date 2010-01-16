#!/usr/bin/perl

sub init_db {
	
	unlink "db.sqlite";

	my $db = 'sqlite';
	
	if ($db eq 'pg') {
	
		$ENV{DBI_DSN}  ||= 'DBI:Pg:dbname=perltests';
		$ENV{DBI_USER} ||= '';
		$ENV{DBI_PASS} ||= '';
	
	} elsif ($db eq 'mysql') {
	
		$ENV{DBI_DSN}  ||= 'DBI:mysql:database=perltests';
		$ENV{DBI_USER} ||= '';
		$ENV{DBI_PASS} ||= '';
	
	} elsif ($db eq 'sqlite') {

		$ENV{DBI_DSN}  ||= 'DBI:SQLite:dbname=db.sqlite';
		$ENV{DBI_USER} ||= '';
		$ENV{DBI_PASS} ||= '';
	
	}
	
	my $dbh = DBI->connect;
	
	my $serial_type = 'integer';
	my $serial_suffix = 'autoincrement';
	if ($ENV{DBI_DSN} =~ /^DBI:(?:mysql|pg)/i) {
		$serial_type = 'serial'; # 'integer';
		$serial_suffix = ''; # 'auto_increment';
	}
	
	$dbh->do ('drop table if exists account');
	# without prefix
	$dbh->do (qq[
		create table account (
			account_id $serial_type primary key $serial_suffix,
			name text not null,
			pass text not null default "abracadabra",
			meta text
		);
	]);
	
	# prefixed
	
	$dbh->do ('drop table if exists contact');
	$dbh->do (qq[create table contact (
			contact_id $serial_type primary key $serial_suffix,
			contact_type text,
			contact_value text,
			contact_active integer default 1,
			account_id integer not null
		);
	]);
	
	$dbh->do ('drop table if exists passport');
	$dbh->do (qq[create table passport (
			id $serial_type primary key $serial_suffix,
			passport_type text,
			passport_value text,
			account_id integer not null
		);
	]);

	$dbh->do ('drop table if exists address');
	$dbh->do (qq[create table address (
			address_id $serial_type primary key $serial_suffix,
			address_country text,
			address_city text,
			address_line text
		);
	]);
	
	$dbh->do ('drop table if exists account_address');
	$dbh->do (qq[create table account_address (
			account_id integer not null,
			address_id integer not null
		);
	]);
	
	return $dbh;
}

sub finish_db {
	unlink "db.sqlite"
		unless $ENV{DEBUG};
}

1;
