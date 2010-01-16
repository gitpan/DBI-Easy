#!/usr/bin/perl

use Class::Easy;

use Data::Dumper;

use Test::More qw(no_plan);

use DBI;

BEGIN {
	
	$Class::Easy::DEBUG = 'immediately';
	
	use_ok 'DBI::Easy';
	use_ok 'DBD::SQLite';
	
	push @INC, 't', 't/DBI-Easy';
	require 'db-config.pl';
	
	my $dbh = &init_db;
	
	DBI::Easy->dbh ($dbh);
	
};

my $ACC  = 'DBI::Easy::Test::Account';
my $CONT = 'DBI::Easy::Test::Contact';

use_ok $ACC;
use_ok $CONT;

my $account = $ACC->new ({name => 'apla', meta => 'pam-pam'});

my $table_name = $account->table_name;

ok ($table_name eq 'account');

ok ($account);
ok (ref $account eq $ACC);

ok ($account->name eq 'apla'); 
ok ($account->meta eq 'pam-pam', 'table test finished');

$account->create;

ok $account->id;

$account->meta ('pam-pam-pam');

ok $account->save;

my $db_account = ref($account)->fetch_by_id ($account->id);

ok $db_account->meta eq 'pam-pam-pam', 'update by pk test';

ok $db_account->delete;

$db_account = ref($account)->fetch_by_id ($account->id);

ok !$db_account;

#my $test_view = $PKG_VIEW->new ({user => 'apla', param => 'pam-pam'});
#
#warn Dumper $test_view->cols;

my $contact = $CONT->new ({type => 'email', value => 'apla@localhost', account_id => $account->id});

my $cols = $contact->cols;

ok (scalar keys %$cols);

ok ($contact->type eq 'email');
ok ($contact->value eq 'apla@localhost');

# now we insert record to db
ok $contact->create, 'inserted';

# must be not null
ok $contact->id, 'id updated after insert';

# but record not updated to actual data, changed only pk column value
ok ! $contact->active, 'but active field not updated';

# now we fetch by pk column;
my $contact_clone = $CONT->fetch_by_id ($contact->id);

ok $contact_clone->active;

$contact_clone->value ('apla@local');

ok $contact->type eq 'email';

$contact_clone->save;

$contact = $CONT->fetch_by_id ($contact->id, [qw(id value active)]);

ok $contact->active;

ok $contact->value eq 'apla@local', "contact value is: " . $contact->value;

ok ! $contact->type, 'type defined and exists, but not fetched';

make_accessor ($CONT, 'dump_fields_include', default => [qw(value type id)]);

ok scalar keys %{$contact->TO_JSON} eq 2;

#warn '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!';
#warn Dumper $contact->TO_JSON;
#warn '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!';

&finish_db;
