package DBI::Easy::Test::Account;

use strict;

use DBI::Easy::Record;
use base qw(DBI::Easy::Record);

use Class::Easy;

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
	
	$t->lap ('dump_fields_include');
	
	my $fields = $self->dump_fields_include ({
		map {$_ => 1}
			qw(name id meta) # without password;
	});
	
	$t->end;
	
	return $fields;
}

1;