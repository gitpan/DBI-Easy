package DBI::Easy::Record::Collection;

use strict;

use DBI::Easy;
use base qw(DBI::Easy);

use Class::Easy;

our $wrapper = 1;

has 'filter', is => 'rw', default => {};
has 'join_table', is => 'rw';

sub new_record {
	my $self   = shift;
	my $params = shift || {};
	
	my $rec_pack = $self->record_package;
	
	my $rec = $rec_pack->new ({%$params, %{$self->filter || {}}});
}

sub natural_join {
	my $self   = shift;
	
	my $join = join ' ', map {'natural join ' . $_->table_quoted} @_;
	$self->join_table ($join);
}

sub make_sql_and_bind {
	my $self = shift;
	my $method = shift;
	my $set    = shift;
	my $where  = shift || {};
	my $suffix = shift || '';

	my $bind_suffix = shift;
	
	my $ref = ref $self;
	
	my $_where = {};
	
	my $filter = $self->filter;
	
	my @params = ([
		$self->fields_to_columns ($filter),
		$self->fields_to_columns ($where)
	], $suffix);
	
	if ($method eq 'sql_update') {
		unshift @params, $self->fields_to_columns ($set);
	}
	
	my ($select, $bind) = $self->$method (@params);
	
	push @$bind, @{$bind_suffix || []};
	
	debug 'sql: \'', $select, '\' => ', defined $bind ? join ', ', @$bind : '[empty]';
	
	return ($select, $bind);
	
}

sub list {
	my $self   = shift;
	
	my ($sql, $bind) = $self->make_sql_and_bind ('sql_select', undef, @_);
	
	my $db_result = $self->fetch_arrayref ($sql, $bind);
	
	debug "result count: ", $#$db_result+1;
	
	$self->columns_to_fields_in_place ($db_result);
	
	return $db_result;
}

sub update {
	my $self   = shift;
	
	my ($sql, $bind) = $self->make_sql_and_bind ('sql_update', @_);
		
	my $db_result = $self->no_fetch ($sql, $bind);
	
	debug "result count: ", $db_result;
	
	return $db_result;
}


sub count {
	my $self   = shift;
	
	my ($select, $bind) = $self->make_sql_and_bind ('sql_select_count', undef, @_);
	
	my $db_result = $self->fetch_single ($select, $bind);
	
	debug "result count: ", $db_result;
	
	return $db_result;
	
}

sub delete {
	my $self   = shift;
	
	my ($sql, $bind) = $self->make_sql_and_bind ('sql_delete', undef, @_);
		
	my $db_result = $self->no_fetch ($sql, $bind);
	
	debug "result count: ", $db_result;
	
	return $db_result;
}

sub tree {
	my $self   = shift;
	my $keys   = shift;
	my $where  = shift;
	my $suffix = shift;
	
	my $ref = ref $self;

	my $where_w_filter = $where;
	my $filter = $self->filter;
	$where_w_filter = {%$where, %$filter}
		if defined $filter and ref $filter eq 'HASH';
	
	my $where_prefixed = $self->fields_to_columns ($where_w_filter);
	
	my ($select, $bind) = $self->sql_select ($where_prefixed, $suffix);
	
	# warn $select, ' => ', defined $bind ? join ', ', @$bind : '[empty]';
	
	my $db_result = $self->fetch_hashref ($select, $keys, $bind);
	#my $db_result = $self->fetch_arrayref ($select, $bind);
	
	$self->columns_to_fields_in_place ($db_result, $keys);
	
	return $db_result;
	
}

sub item {
	my $self   = shift;
	my $where  = shift;
	my $suffix = shift || '';
	
	my $result = $self->list ($where, $suffix . ' limit 1');
	
	# programmer must be warned about multiple values
	return $result->[0];
}

sub new_record_from_request {
	my $self    = shift;
	my $request = shift;

	my $rec_pack = $self->record_package;
	
	my $rec = $rec_pack->new ({%{$self->filter}});
	$rec->apply_request_params ($request);
	
	return $rec;
}

sub columns_to_fields_in_place {
	my $self     = shift;
	my $records  = shift;
	
	my $rec_pack = $self->record_package;
	
	if (UNIVERSAL::isa ($records, 'ARRAY')) {
	
		foreach my $record_counter (0 .. $#$records) {
			
			my $record = $records->[$record_counter];
			
			bless $record, $rec_pack;
			$record->columns_to_fields_in_place;
		}
	} elsif (UNIVERSAL::isa ($records, 'HASH')) {
	
		foreach my $record_key (keys %$records) {
			
			my $record = $records->{$record_key};
			
			bless $record, $rec_pack;
			$record->columns_to_fields_in_place;
		}
	}
}

our $MAX_LIMIT = 300;

sub ordered_list {
	my $self = shift;
	
	my $order = shift;
	my $dir   = shift;
	my $limit = shift;
	my $start = shift;
	
	my $filter = shift;
	my $bind   = shift || [];
	
	my $fields = $self->fields;
	
	my $sort_col;
	if (exists $fields->{$order}) {
		$sort_col = $fields->{$order}->{quoted_column_name};
	} elsif ($self->pri_key) {
		# we assume primary key ordering unless ordered column known
		$sort_col = $fields->{$self->pri_key}->{quoted_column_name};
	}
	
	if ($dir =~ /^(asc|desc)$/i) {
		$dir = lc($1);
	} else {
		$dir = ''; # default sort
	}
	
	# When using LIMIT, it is important to use an ORDER BY clause that
	# constrains the result rows into a unique order. Otherwise you will
	# get an unpredictable subset of the query's rows. You might be asking
	# for the tenth through twentieth rows, but tenth through twentieth
	# in what ordering? The ordering is unknown, unless you specified ORDER BY.
	if (!$sort_col or $start !~ /\d+/ or $limit !~ /\d+/) {
		return {
			count => 0,
			error => "ordering-undefined"
		};
	}
	
	$start =~ s/(\d+)/$1/;
	$limit =~ s/(\d+)/$1/;
	
	my $count = $self->count ($filter, '', $bind);

	if ($start > $count) {
		$start = $count - $limit;
		$start = 0 if $start < 0;
	}
	
	if ($limit > $MAX_LIMIT or ! $limit > 0) { # try undef -)
		$limit = $MAX_LIMIT;
	}

	my $suffix = "order by $sort_col $dir limit $limit offset $start";
	# debug "suffix: $suffix";
	
	my $list  = $self->list ($filter, $suffix, $bind);

	return {
		items => $list,
		total_count => $count,
		version => 1,
	};
	
	
}

1;
