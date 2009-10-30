package DBI::Easy::Record;
# $Id: Record.pm,v 1.6 2009/07/20 18:00:08 apla Exp $

use Class::Easy;

use DBI::Easy;
use base qw(DBI::Easy);

our $wrapper = 1;

has 'dump_fields_include', default => {}, is => 'rw', global => 1;

sub _init {
	my $self = shift;
	
	$self->{'+fetched'} = 0;
	
}

sub save {
	my $self = shift;
	
	my $result;
	
	my $pk = $self->_pk_;
	
	if (($pk and $pk ne '' and $self->$pk) or $self->fetched) {
		# try to update
		$result = $self->update;
	} else {
		$result = $self->create;
	}
}

sub fetched {
	return shift->{'+fetched'};
}

# update by pk
sub update {
	my $self = shift;
	
	my ($sql, $bind) = $self->sql_update_by_pk (@_);
	
	debug "sql: $sql => " . (defined $bind and scalar @$bind ? join ', ', @$bind : '[]');
	
	return $self->no_fetch ($sql, $bind);
	
}

# delete by pk
sub delete {
	my $self = shift;
	
	my ($sql, $bind) = $self->sql_delete_by_pk (@_);
	
	debug "sql: $sql => " . (defined $bind and scalar @$bind ? join ', ', @$bind : '[]');
	
	return $self->no_fetch ($sql, $bind);
	
}

sub create {
	my $self = shift;
	
	my $t = timer ('fields to columns translation');
	
	my $fields = $self->fields_to_columns;
	
	$t->lap ('sql generation');
	
	my ($sql, $bind) = $self->sql_insert ($fields);
	
	$t->lap ('insert');
	
	# sequence is available for oracle insertions
	my $pk_col = $self->_pk_column_;
	my $seq;
	
	if ($pk_col and exists $fields->{"_$pk_col"} and $fields->{"_$pk_col"} =~ /^\s*(\w+)\.nextval\s*$/si) {
		$seq = $1;
	}

	my $id = $self->no_fetch ($sql, $bind, $seq); 
	
	$t->lap ('perl wrapper for id');
	
	return unless defined $id;
	
	return $id if $id =~ /^0E\d+$/;
	
	my $pk = $self->_pk_;
	
	$self->$pk ($id)
		if $pk; # sometimes no primary keys in table
	
	$t->end;
	
	$t->total;
	
	return 1;
}

sub fetch {
	my $class   = shift;
	my $params  = shift;
	my $cols    = shift;
	
	my $prefixed_params = $class->fields_to_columns ($params);
	
	my ($statement, $bind) = $class->sql_select ($prefixed_params, undef, $cols);
	
	debug "sql: '$statement'";
	
	my $record = $class->fetch_row ($statement, $bind);
	
	return
		unless ref $record;
	
	bless $record, $class;
	
	$record->columns_to_fields_in_place;
	
	$record->{'+fetched'} = 1;
	
	return $record;
}

sub fetch_or_create {
	my $class = shift;
	my $params = shift;
	
	my $record = $class->fetch ($params);
	
	unless (defined $record) {
		$record = $class->new ($params);
		$record->create;
	}
	
	return $record;
}

# example usage: $domain->is_related_to ('contacts', {
# 	isa => 'My::Entity::Contact::Collection',
# 	relation => [domain_key => domain_key_in_contacts], # optional, by default natural join
# 	many_to_many => 'My::Entity::Domain_Contact::Collection',
# 	filter => {}
# });

# памятка использования is_related_to
#$ref->is_related_to (
#	‘entity’,  # название сущности, доступной у объекта
#	           # после вызова этого метода
#	‘entity_pack’, # имя класса, корое используется в 
#	               # качестве фабрики для сущностей
#	filter => {}, # хэш фильтров для ограничения выборки
#	relation => ['key_in_ref', 'key_in_entity'] # отношение
#);

sub is_related_to {
	my $ref    = shift;
	my $entity = shift;
	my $pack   = shift;
	my %params = @_;

	my $t = timer ('all');
	
	debug "$entity";
	
	my $filter = $params{filter} || {};
	
	$params{relation} = []
		unless defined $params{relation};
	
	my $column     = $params{relation}->[0] || $ref->_pk_;
	my $ref_column = $params{relation}->[1] || ($ref->prefix
		? $ref->prefix
		: $ref->table . '_'
	) . $column;
	
	try_to_use ($pack);
	
	# warn "column $column from table ".$ref->table." is related to column $ref_column from table ". $pack->table;
	
	my $sub;
	my $ref_sub;
	
	
	if ($pack->is_collection) {
		$sub = sub {
			my $self = shift;
			
			return $pack->new ({filter => {%$filter, $ref_column => $self->$column}});
		};
		$ref_sub = sub {
			my $self = shift;
			
			return $pack->new ({filter => {%$filter, $ref_column => $self->$column}});
		};
	} else {
		
		$sub = sub {
			my $self = shift;
			
			return $pack->fetch_or_create ({%$filter, $ref_column => $self->$column});
		};
	}
	
	make_accessor ($ref, $entity, default => $sub);
	
	$t->end;
}

sub validation_errors {
	my $self = shift;
	
	my $errors = {};
	
	debug "field validation";
	
	foreach my $field (keys %{$self->fields}) {
		# first, we need to validate throught db schema
		# TODO
		if (0) {
			$errors->{$field} = 'schema-validation-error';
		}
		# second, we validate throught custom validators
		my $method = "${field}_valid";
		if ($self->can ($method)) {
			debug "custom validation for $field";
			my $error_code = $self->$method;
			if ($error_code) {
				$errors->{$field} = $error_code;
				debug "failed: $error_code";
			}
		}
	}
	
	return unless scalar keys %$errors;
	
	return $errors;
}

sub dump_fields_exclude {
	 #TODO
}

sub TO_JSON {
	my $self = shift;
	
	my $allowed = $self->dump_fields_include;
	if (scalar keys %$allowed) {
		return {
			map {$_ => $self->{$_}} 
			grep {exists $allowed->{$_}} 
			keys %$self
		};
	} else {
		return {%$self};
	}
}

sub apply_request_params {
	my $self   = shift;
	my $request = shift;
	
	foreach my $field (keys %{$self->fields}) {
		# TODO: check for primary key. we don't want primary key value here
		my $value = $request->param ($field);
		next if !defined $value or $value eq '';
		$self->{$field} = $value;
	}

	my $values = {};
	
	foreach my $field (keys %{$self->columns}) {
		# TODO: check for primary key. we don't want primary key value here
		my $value = $request->param ($field);
		next if !defined $value or $value eq '';
		$values->{$field} = $value;
	}
	
	my $fields = $self->columns_to_fields ($values);

	foreach my $field (keys %{$fields}) {
		my $value = $fields->{$field};
		next if !defined $value or $value eq '';
		$self->{$field} = $value;
	}
}

1;