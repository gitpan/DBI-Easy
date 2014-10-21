#!/usr/bin/perl -I../../../perl-easy/lib

use Class::Easy;

use Data::Dumper;

use Test::More qw(no_plan);

use DBI;

BEGIN {

	use_ok 'DBI::Easy';
	use_ok 'DBD::SQLite';
	
	push @INC, 't', 't/DBI-Easy';
	require 'db-config.pl';
	
	my $dbh = &init_db;
	
	DBI::Easy->dbh ($dbh);
	
};

my $dbh = DBI::Easy->dbh;

my $ACC  = 'DBI::Easy::Test::Account';
my $COLL = 'DBI::Easy::Test::Contact::Collection';

use_ok ($ACC);
use_ok ($COLL);

my $account = $ACC->new ({name => 'apla'});

ok $account;

# $PKG->is_related_to ('records2', $COLL);

$account->create;

my $account2 = $ACC->new ({name => 'gaddla'});

$account2->create;

my $collection = $account->contacts;

ok $collection;

ok $collection->filter->{'account_id'} == $account->id,
	'account id transferred to filter';

my $collection2 = $account2->contacts;

ok $collection2->filter->{'account_id'} == $account2->id;

my $count = $collection->count;
ok $count == 0, "items in collection = $count";

my $contact = $collection->new_record ({type => 'email', value => 'apla@flo.local'});

ok $contact->account_id == $account->id;

# diag Dumper $sub_record;

$contact->create;

$contact = $collection->new_record ({type => 'email', value => 'apla-subscriptions@flo.local'});

$contact->create;

$count = $collection->count;
ok $count == 2, "items in collection = $count";

my $passport = $account->passport ({type => 'ABC', value => '123123123'});

ok $passport->account_id == $account->id;

$Class::Easy::DEBUG = 'immediately';

my $like_apla = $collection->list;

ok @$like_apla == 2;

$like_apla = $collection->list ({_value => 'like :username', ':username' => 'apla%'});

ok @$like_apla == 2, 'first like';

$like_apla = $collection->list ("contact_value like 'apla\%'");

ok @$like_apla == 2, 'first like 2';

my $limited = $collection->list ("contact_value like 'apla\%' limit 1");

ok @$limited == 1, 'limited';

ok $collection->count ("contact_value like 'apla\%'") == 2;

$like_apla = $collection->list ("contact_value like ?", undef, ['apla%']);

ok @$like_apla == 2, 'second like';

ok $collection->count ("contact_value like ?", undef, ['apla%']) == 2;

my $collection3 = $COLL->new;

ok @{$collection3->list} == 2;
ok $collection3->count == 2;

ok @{$collection3->list ({type => 'email'})} == 2;
ok $collection3->count ({type => 'email'}) == 2;

my $address_fields = {line => 'test str', city => 'usecase', country => 'testania'};

ok $collection->update ({type => 'e-mail'}) == 2;
ok $collection->count  ({type => 'e-mail'}) == 2;


#my $address  = $account->addresses->new_record ($address_fields);
#$address->save;

#my $address2 = $account2->addresses->new_record ($address_fields);
#$address2->save;

1;

