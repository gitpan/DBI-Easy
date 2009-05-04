package DBI::Easy;

# use Hash::Merge;

use Class::Easy;

sub statement {
	my $self      = shift;
	my $statement = shift;
	
	my $dbh = $self->dbh;
	
	my $sth;
	if (ref $statement eq 'DBI::st') {
		$sth = $statement;
	} elsif (ref $statement) {
		die "can't use '$statement' as sql statement";
	} else {
		
		my $prepare_method = $self->prepare_method;
		$sth = $dbh->$prepare_method (($statement, {}, $self->prepare_param));
	}
	
	return $sth;
}

# for every query except select we must use this routine
sub no_fetch {
	my $self = shift;
	my $statement = shift;
	my $params = shift;
	
	$params = [defined $params ? $params : ()]
		unless ref $params;
	
	my $dbh = $self->dbh;
	my $rows_affected;
	
	eval {
		my $sth = $self->statement ($statement);
		$rows_affected = $sth->execute(@$params);
		
		$sth->finish;
		
		$rows_affected = $dbh->last_insert_id (
			undef,
			undef,
			$self->table,
			$self->pri_key_column
		)
			if ! ref $statement and $statement =~ /^\s*insert/io;
		
	};
	
	return 0 if $self->_dbh_error ($@);
	
	return $rows_affected;
}

sub fetch_single {
	my $self = shift;
	my $statement = shift;
	my $params = shift;
	
	$params = [defined $params ? $params : ()]
		unless ref $params;
	
	my $dbh = $self->dbh;
	
	my $single;
	eval {
		
		my $sth = $self->statement ($statement);

		die unless $sth->execute(@$params);
		
		$sth->bind_columns (\$single);
 
		$sth->fetch;
	};
	
	return if $self->_dbh_error ($@);
	
	return $single;
}

sub fetch_column {
	my $self = shift;
	my $statement = shift;
	my $params = shift;
	
	$params = [defined $params ? $params : ()]
		unless ref $params;
	
	my $dbh = $self->dbh;
	
	my $single;
	my $column;
	eval {
		my $sth = $dbh->prepare_cached($statement, {}, 3);

		$sth->execute(@$params);

		$sth->bind_columns(\$single);
 
		while ($sth->fetch) {
			push @$column, $single;
		}
	};
	
	return if $self->_dbh_error ($@);
	
	return $column;
}

sub fetch_columns {
	my $self = shift;
	my $statement = shift;
	my $params = shift;
	
	$params = [defined $params ? $params : ()]
		unless ref $params;
	
	my $dbh = $self->dbh;
	
	my $columns = [];
	eval {
		my $sth = $dbh->prepare_cached($statement, {}, 3);

		$sth->execute(@$params);

		while (my @arr = $sth->fetchrow_array) {
			foreach (0 .. $#arr) {
				push @{$columns->[$_]}, $arr[$_];
			}
		}
	};
	
	return if $self->_dbh_error ($@);
	
	return $columns;
}

sub fetch_row {
	my $self = shift;
	my $statement = shift;
	my $params = shift;
	
	$params = [defined $params ? $params : ()]
		unless ref $params;
	
	my $dbh = $self->dbh;
	
	my $row;
	eval {
		my $sth = $dbh->prepare_cached($statement, {}, 3);

		$row = $dbh->selectrow_hashref ($sth, {}, @$params);
	};
	
	return if $self->_dbh_error ($@);
		
	return $row;
}

sub fetch_row_in_place {
	my $self = shift;
	
	my $row = $self->fetch_row (@_);
	
	# Hash::Merge::set_clone_behavior (0);

	# Hash::Merge::specify_behavior(
		{
			'SCALAR' => {
				'SCALAR' => sub { $_[1] },
				'ARRAY'  => \&strict_behavior_error,
				'HASH'   => \&strict_behavior_error,
			},
			'ARRAY' => {
				'SCALAR' => \&strict_behavior_error,
				'ARRAY'  => sub { $_[1] },
				'HASH'   => \&strict_behavior_error, 
			},
			'HASH' => {
				'SCALAR' => \&strict_behavior_error,
				'ARRAY'  => \&strict_behavior_error,
				'HASH'   => sub { Hash::Merge::_merge_hashes( $_[0], $_[1] ) }, 
			},
		}, 
		'Strict Override', 
	#);
	
	# return unless "$structure" =~ /^(?:([^=]+)=)?([A-Z]+)\(0x([^\)]+)\)$/;
	#	
	# my ($type, $address) = ($2, $3);
	
	# warn Dumper $self, $row;
	
	# Hash::Merge::merge ($self, $row);
	
	# warn Dumper $self;
}

sub strict_behavior_error {
	die "'", ref $_[0], "' to '", ref $_[1], "' not supported";
}

sub fetch_hashref {
	my $self = shift;
	my $statement = shift;
	my $key = shift;
	my $params = shift;
	$params ||= [];

	my $dbh = $self->dbh;
	my $result;
	my $rows_affected;

	eval {
		my $sth = $self->statement ($statement);
		
		$rows_affected = $sth->execute (@$params);
		$result = $sth->fetchall_hashref($key);
	};

	return if $self->_dbh_error ($@);

	return $result;
}

sub fetch_arrayref {
	my $self = shift;
	my $statement = shift;
	my $params = shift;
	$params ||= [];
	
	my $sql_args = shift;
	$sql_args ||= {Slice => {}, MaxRows => undef};
	
	my $fetch_handler = shift;
	
	my $dbh = $self->dbh;
	my $result;
	my $rows_affected;

	eval {
		my $sth = $self->statement ($statement);
		$rows_affected = $sth->execute (@$params);
		$result = $sth->fetchall_arrayref ($sql_args->{Slice}, $sql_args->{MaxRows});
	};

	return if $self->_dbh_error ($@);

	return $result;
}

sub fetch_handled {
	my $self = shift;
	my $statement = shift;
	my $params = shift;
	$params ||= [];
	
	my $fetch_handler = shift;
	
	my $dbh = $self->dbh;
	my $result;
	my $rows_affected;

	eval {
		my $sth = $self->statement ($statement);
		$rows_affected = $sth->execute (@$params);
		while (my $row = $sth->fetchrow_hashref) {
			&$fetch_handler ($row);
		}
	};

	return if $self->_dbh_error ($@);

	return $rows_affected;
}


1;