package DBI::Easy;

use Class::Easy;

use DBI 1.601;

use vars qw($VERSION);
$VERSION = '0.01';

# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
# interface splitted to various sections:
# sql generation stuff prefixed with sql and located
# at DBI::Class::SQL
# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

use DBI::Easy::SQL;

# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
# real dbh operations contains methods fetch_* and no_fetch
# and placed in DBI::Class::DBH
# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

use DBI::Easy::DBH;

use DBI::Easy::DriverPatcher;

# bwahahahaha
our %GREP_COLUMN_INFO = qw(TYPE_NAME 1 mysql_values 1);

our $wrapper = 1;

sub new {
	my $class  = shift;
	my $params = shift;
	
	$params ||= {};

	bless $params, $class;
	
	$params->_init
		if $params->can ('_init');
	
	return $params;
}

sub import {
	my $class = shift;
	
	no strict 'refs';
	no warnings 'once';
	
	make_accessor ($class, 'dbh', is => 'rw', global => 1)
		unless ${"${class}::imported"};
	

	if (! ${"${class}::wrapper"} and $class ne __PACKAGE__ and ! ${"${class}::imported"} ) {
		
		debug "importing $class";
		
		my $t = timer ('init_class');
		$class->_init_class;
		
		$t->lap ('init_db');
		
		# we call _init_db from package before real db 
		$class->_init_db;
		
		$t->lap ("init_collection $class");
		
		$class->_init_collection
			if $class->is_collection;
		
		$t->lap ("dbh check and accessors $class");
		
		die "can't use database class '$class' without db connection: $DBI::errstr"
				if ! $class->dbh or $class->dbh eq '0E0';

		die "can't retrieve table '".$class->table."' columns for '$class'"
			unless $class->_init_make_accessors;
		
		$t->lap ("init_last $class");
		
		$class->_init_last;
		
		$t->end;
		
		# my $driver = $class->dbh->get_info (17);
		# warn "driver name from get_info ($DBI::Const::GetInfoType{SQL_DBMS_NAME}): $driver";
	}
	
	${"${class}::imported"} = 1;
	
	$class::SUPER->import (@_)
		if (defined $class::SUPER);
	
}

sub _init_db {
	my $self = shift;
	$self->dbh (DBI->connect);
}

sub _init_class {
	my $self = shift;

	my $ref  = ref $self || $self;
	
	my @pack_chunks = split /\:\:/, $ref;
	
	my $is_collection = 0;
	
	# fix for collections
	if ($pack_chunks[-1] eq 'Collection') {
		pop @pack_chunks;
		
		make_accessor ($ref, 'record_package', is => 'rw', global => 1);
		
		$is_collection = 1;
		
	} elsif ($pack_chunks[-1] eq 'Record') {
		pop @pack_chunks;
	}
	
	make_accessor ($ref, 'is_collection', default => $is_collection);
	
	my $table_name = lc join ('_', split /(?=\p{IsUpper}\p{IsLower})/, $pack_chunks[-1]);
	
	# dies when this method called without object reference;
	# expected behaviour
	
	make_accessor ($ref, 'table', is => 'rw', global => 1,
		default => $table_name);
	make_accessor ($ref, 'prefix', is => 'rw', global => 1,
		default => "${table_name}_");
	
	make_accessor ($ref, 'fetch_fields', is => 'rw', default => '*');
	
	make_accessor ($ref, 'prepare_method',  is => 'rw', global => 1,
		default => 'prepare_cached');
	make_accessor ($ref, 'prepare_param', is => 'rw', global => 1,
		default => 3);
	make_accessor ($ref, 'undef_as_null', is => 'rw', global => 1,
		default => 0);

}

sub _init_collection {
	my $self = shift;
	
	my $rec_pkg = $self->record_package;
	
	unless ($rec_pkg) {
		my $ref  = ref $self || $self;
	
		my @pack_chunks = split /\:\:/, $ref;
		
		pop @pack_chunks;
		
		$rec_pkg = join '::', @pack_chunks;
		
		unless (try_to_use ($rec_pkg)) {
			warn $@;
			$rec_pkg = join '::', @pack_chunks, 'Record';
			die unless (try_to_use ($rec_pkg));
		}
		
		$self->record_package ($rec_pkg);
	}
	
}

# here we retrieve fields and create make_accessors
sub _init_make_accessors {
	my $class = shift;
	
	my $table  = $class->table;
	my $prefix = $class->prefix;
	
	my $t = timer ('columns info wrapper');
	
	my $cols = $class->_dbh_columns_info;
	
	$t->end;
	
	make_accessor ($class, 'cols', default => $cols);
	make_accessor ($class, 'columns', default => $cols);
	
	my $fields = {};
	
	make_accessor ($class, 'fields', default => $fields);
	
	my $pri_key;
	my $pri_key_column;
	
	foreach my $col_name (keys %$cols) {
		my $col_meta = $cols->{$col_name};
		# here we translate rows
		my $field_name = $col_name;
		
		if (defined $prefix and $prefix ne '' and $col_name =~ /^$prefix(.*)/) {
			$field_name = $1;
		}
		
		# field meta referenced to column meta
		# no we can use $field_meta->{col_name} and $col_meta->{field_name}
		$fields->{$field_name} = $col_meta;
		
		$col_meta->{field_name} = $field_name;
		
		if ($col_meta->{TYPE_NAME} eq 'ENUM' and $#{$col_meta->{mysql_values}} >= 0) {
			make_accessor ($class, "${field_name}_variants",
				default => $col_meta->{mysql_values});
		}
		
		if (exists $col_meta->{X_IS_PK} and $col_meta->{X_IS_PK} == 1) {
			
			if ($pri_key) {
				warn "multiple pri keys: $fields->{$pri_key}->{column_name} and $field_name";
			} else {
				$pri_key = $field_name;
				$pri_key_column = $col_name;
			} 
			
			make_accessor ($class, "fetch_by_$field_name", default => sub {
				my $package = shift;
				my $value   = shift;
				
				return $package->fetch ({$field_name => $value}, @_);
			});
		}
		
		make_accessor ($class, $field_name, is => 'rw');
	}
	
	make_accessor ($class, 'pri_key', default => $pri_key);
	make_accessor ($class, 'pri_key_column', default => $pri_key_column);
	
	return $class;
}

sub _init_last {

}

sub _dbh_columns_info {
	my $class = shift;
	
	my $ts = timer ('inside columns info');
	
	my $table = $class->table;
	my $dbh = $class->dbh;
	
	$ts->lap ('make accessor');
	
	# preparations
	make_accessor ($class, 'table_quoted', 
		default => $dbh->quote_identifier ($table));
	
	my $real_row_count = 0;
	
	my $column_info = {};
	
	$ts->lap ('eval column info');
	
	eval {
	
		my $t = timer ('column info call');
		
		my $sth = $dbh->column_info(
			undef, undef, $table, '%'
		);
		
		$t->lap ('execute');
		
		$sth->execute;

		$t->lap ('fetchrow hashref');
		
		while (my $row = $sth->fetchrow_hashref) {
			$real_row_count ++;
			
			my $column_name = $row->{COLUMN_NAME};
			
			$column_info->{$column_name} = {
				(map {
					$_ => $row->{$_}
				} grep {
					exists $GREP_COLUMN_INFO{$_}
				} keys %$row),
				
				column_name => $column_name,
				quoted_column_name => $dbh->quote_identifier ($column_name),
			};
		}
		
		$t->end;
		
		$t->total;
		
		if ($real_row_count == 0) {
			die "no rows for table '$table' fetched";
		}
	};
	
	$ts->lap ('_dbh_error');
	
	return
		if $class->_dbh_error ($@);
	
	$real_row_count = 0;
	
	$ts->lap ('primary_key_info');
	
	eval {
	
		my $t = timer ('primary key');
		
		my $sth = $dbh->primary_key_info(
			undef, undef, $table
		);
		
		$t->lap ('execute');
		
		$sth->execute;
		
		$t->lap ('fetchrow');

		while (my $row = $sth->fetchrow_hashref) {
			$real_row_count ++;
			# here we translate rows
			my $pri_key_name = $row->{COLUMN_NAME};
			
			$column_info->{$row->{COLUMN_NAME}}->{X_IS_PK} = 1;
		}
		
		$t->end;
		
		$t->total;
		
		if ($real_row_count == 0) {
			# warn "no primary keys for table '$table'";
		}
	};
	
	
	
	return
		if $class->_dbh_error ($@);
	
	$ts->end;
	
	return $column_info;
}

sub _dbh_error {
	my $self  = shift;
	my $error = shift;
	my $statement = shift;
	
	return unless $error;
	
	my @caller = caller (1);
	my @caller2 = caller (2);
	
	warn ("[db error at $caller[3] ($caller[2]) called at $caller2[3] ($caller2[2])] ",
		$error
	);
	
	if ($self->{in_transaction}) {
		eval {$self->rollback};
		die $error;
	}
	
	if ($DBI::Easy::ERRHANDLER and ref $DBI::Easy::ERRHANDLER eq 'CODE') {
		&$DBI::Easy::ERRHANDLER ($self, $error, $statement);
	}
	
	return 1;
}


# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
# we always work with one table or view.
# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

sub _prefix_manipulations {
	my $self   = shift;
	my $dir    = shift;
	my $values = shift || $self;
	my $in_place = shift || 0;
	
	return $values if ! ref $values;
	
	my $entities;
	my $ent_key;
	if ($dir eq 'fields2cols') {
		$entities = $self->fields;
		$ent_key = 'column_name';
	} elsif ($dir eq 'cols2fields') {
		$entities = $self->cols;
		$ent_key = 'field_name';
	} else {
		die "you can't call _prefix_manipulations without direction";
	}
	
	if ($in_place) {
		map {
			$values->{$entities->{$_}->{$ent_key}} = delete $values->{$_}
		} grep {
			exists $entities->{$_}
		} keys %$values;
	} else {
		my @defined_keys = grep {
			exists $entities->{$_}
				&& ($self->undef_as_null || defined $entities->{$_})
		} keys %$values;
		
		my %defined = map {
			$entities->{$_}->{$ent_key} => $values->{$_}
		} @defined_keys;
		
		return \%defined;
	}
}

sub fields_to_columns {
	my $self = shift;
	
	$self->_prefix_manipulations ('fields2cols', shift, 0);
}

sub columns_to_fields {
	my $self = shift;
	
	$self->_prefix_manipulations ('cols2fields', shift, 0);
}

sub columns_to_fields_in_place {
	my $self = shift;
	
	$self->_prefix_manipulations ('cols2fields', shift, 1);
}

sub pk_fields_prefixed {
	my $self = shift;
	
	return $self->fields_prefixed (1);
}

sub remove_prefix_in_place {
	my $self   = shift;
	
	my $col_trans = {reverse %{$self->_col_trans}};
	
	foreach my $col (keys %$self) {
		
		my $field = $col_trans->{$col};
		next unless defined $field;
		
		$self->{$field} = delete $self->{$col};
	}
}

sub deprefix_cols {
	my $self = shift;
	my @cols = @_;
	
	my $col_trans = {reverse %{$self->_col_trans}};
	
	my @result = map {$col_trans->{$_}} @cols;
}

# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
# we always work with one table or view.
# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-


# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
# simplified sql execute
# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-



1;

=head1 NAME

DBI::Easy - ORM made easy.

=head1 SYNOPSIS

	package Entity::Passport;

	use Class::Easy;

	use DBI::Easy::Record;
	use base qw(DBI::Easy::Record);

	# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-

	package main;

	use Class::Easy;

	# connect to database
	use Entity::Passport;

	# create new record in memory
	my $passport = Entity::Passport->new ({
		code => '125434534'
	});

	# insert into database
	$passport->save;

=head1 METHODS

=head2 new

TODO

=cut

=head1 AUTHOR

Ivan Baktsheev, C<< <apla at the-singlers.us> >>

=head1 BUGS

Please report any bugs or feature requests to my email address,
or through the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=DBI-Easy>. 
I will be notified, and then you'll automatically be notified
of progress on your bug as I make changes.

=head1 SUPPORT



=head1 ACKNOWLEDGEMENTS



=head1 COPYRIGHT & LICENSE

Copyright 2007-2009 Ivan Baktsheev

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut
