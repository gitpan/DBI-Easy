package DBI::Easy::Helper;

use Class::Easy;
use Time::Piece;

# collection constructor
sub _connector_maker {
	my $class = shift;
	my $type  = shift;
	my $name  = shift; # actually, is entity name
	
	if ($type !~ /^(Collection|Record)$/i) {
		warn "no correct type supplied - '$type' (expecting 'collection' or 'record')";
		return;
	}
	
	my %params = @_;
	my $prefix = $params{prefix} || 'Entity';
	
	my @pack_chunks = ($prefix, package_from_table ($name));
	push @pack_chunks, 'Collection'
		if $type =~ /^collection$/i;
	
	my $pack = join '::', @pack_chunks;
	
	debug "creation package $pack";
	
	# check for existing package
	return $pack
		if eval "scalar keys \%$pack\::;";
	
	my $code;
	
	if ($params{entity}) {
		my $table_name = '';
		$table_name = "has 'table_name', global => 1, is => 'rw', default => '" . $params{table_name} . "';\n"
			if $params{table_name};
		
		$code = "package $pack;\nuse Class::Easy;\nuse base '$params{entity}';\n$table_name; package main;\nimport $pack;\n";
		
	} else {
		warn "error: no entity package provided";
		return;
	}
	
	eval $code;
	
	if ($@) {
		warn "something wrong happens: $@";
		return;
	} else {
		return $pack;
	}
}

# collection constructor
sub c {
	my $self = shift;
	return $self->_connector_maker ('collection', @_);
}

# record constructor
sub r {
	my $self = shift;
	return $self->_connector_maker ('record', @_);
}

sub value_from_type {
	my $pack  = shift;
	my $type  = shift;
	my $value = shift;
	my $dbh   = shift; # check for driver
	
	if (defined $type and ($type eq 'DATE' or $type eq 'TIMESTAMP(6)' or $type eq 'DATETIME' or $type eq 'TIMESTAMP')) {
	
		my $t = localtime;
		my $timestamp = eval {(Time::Piece->strptime ($value, "%Y-%m-%d %H:%M:%S") - $t->tzoffset)->epoch};
		return $timestamp
			if $timestamp;
	}
	
	return $value;
	 
}

sub value_to_type {
	my $pack  = shift;
	my $type  = shift;
	my $value = shift;
	my $dbh   = shift; # check for driver

	if (defined $type and ($type eq 'DATE' or $type eq 'TIMESTAMP(6)' or $type eq 'DATETIME' or $type eq 'TIMESTAMP')) {
		my $timestamp = Time::Piece->new ($value)->strftime ("%Y-%m-%d %H:%M:%S");
		return $timestamp
			if $timestamp;
	}
	
	return $value;

}

sub table_from_package {
	my $entity = shift;
	
	lc join ('_', split /(?=\p{IsUpper}\p{IsLower})/, $entity);
}

sub package_from_table {
	my $table = shift;
	
	join '', map {ucfirst} split /_/, $table;
}

1;

__DATA__
