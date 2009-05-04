#!/usr/bin/perl -I../../../perl-easy/lib

use strict;

use Data::Dumper;

use Test::More qw(no_plan);

use DBI;

BEGIN {

	use_ok 'DBI::Easy';
	use_ok 'DBD::SQLite', 'we need DBD::SQLite for test';
	
	push @INC, 't', 't/DBI-Easy';
	require 'db-config.pl';
	
	my $dbh = &init_db;
	
	DBI::Easy->dbh ($dbh);
	
};

my $dbh = DBI::Easy->dbh;

my $ACC  = 'DBI::Easy::Test::Account';
my $ACCS = 'DBI::Easy::Test::Account::Collection';
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

use Class::Easy;

$Class::Easy::DEBUG = 'immediately';

my $like_apla = $collection->list;

ok @$like_apla == 2;

$like_apla = $collection->list ("contact_value like 'apla\%'");

ok @$like_apla == 2, 'first like';

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

$collection->natural_join ($ACC);

diag Dumper $collection->list;

my $paging = {page_size => 20, count => 1000, page_num => 1, pages_to_show => 8};

my $pager = $collection->pager ({%$paging, page_num => 1});
diag '1 => ', join ', ', @$pager;

$pager = $collection->pager ({%$paging, page_num => 10});
diag '10 => ', join ', ', @$pager;

$pager = $collection->pager ({%$paging, page_num => 3});
diag '3 => ', join ', ', @$pager;

$pager = $collection->pager ({%$paging, page_num => 5});
diag '5 => ', join ', ', @$pager;


# ok ! $collection->count ({contact_type => ''});


#my $items = $collection->

#my $address  = $account->addresses->new_record ($address_fields);
#$address->save;

#my $address2 = $account2->addresses->new_record ($address_fields);
#$address2->save;

1;

