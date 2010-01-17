package DBI::Easy::Test::Account;

use strict;

use DBI::Easy::Record;
use base qw(DBI::Easy::Record);

use Class::Easy;

has 'dump_fields_include', default => [qw(name id meta)]; # without password;

sub _init_last {
	my $self = shift;
	
	my $t = timer ('relations');
	
	$self->is_related_to (
		'contacts', 'DBI::Easy::Test::Contact::Collection'
	);
	
	$t->lap ('relations2');
	
	$self->is_related_to (
		'passport', 'DBI::Easy::Test::Passport'
	);
	
	$t->end;
	
	return $self->dump_fields_include;
}

1;