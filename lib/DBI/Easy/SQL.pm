package DBI::Easy;
# $Id: SQL.pm,v 1.2 2009/03/15 07:33:48 apla Exp $

use strict;
use warnings;

use DBI;

# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
# sql generation stuff
# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

sub sql_range {
	my $self = shift;
	my $length = shift || 0;
	
	if (ref $length eq 'ARRAY') {
		$length = $#$length + 1;
	}  
	
	return
		unless $length > 0;

	return join ', ', ('?') x $length;
} 

sub sql_names_range {
	my $self = shift;
	my $list = shift;
	
	return join ', ', @$list;
} 

sub sql_order {
	my $self  = shift;
	my $field = shift;
	my $dir   = shift;
	
	my $sort_col = $self->fields->{$field}->{quoted_column_name};
	
	if (!$field || !$sort_col || $dir !~ /^(?:asc|desc)$/i) {
		return '';
	}
	
	return "order by $sort_col $dir";
}

sub sql_limit {
	my $self  = shift;
	
	my $s = $#_;
	die if $s > 1 || $s == -1;
	
	return "limit " . join ', ', @_;
}

# get sql statement for insert

sub sql_where {
	my $self = shift;
	my $where_hash = shift;
	
	if (ref $where_hash eq 'ARRAY') {
		
		my (@where_acc, @bind_acc);
		
		foreach (@$where_hash) {
			my ($where, $bind) = $self->sql_where ($_);
			push @where_acc, $where
				if defined $where and $where ne '';
			push @bind_acc,  @{$bind || []};
		}
		
		return join (' and ', @where_acc), \@bind_acc;
	}
	
    my @where;
    my @bind;
    
    return if ! defined $where_hash or $where_hash eq '';
    return $where_hash if !ref $where_hash;
    return if ref $where_hash ne 'HASH' || scalar keys %$where_hash == 0;
    
	foreach my $k (keys %$where_hash) {
		my $qk = $self->dbh->quote_identifier ($k);
        if (ref $where_hash->{$k} eq 'ARRAY') {
        	my $range;
        	if (! scalar @{$where_hash->{$k}}) {
        		$range = 'null';
        	} else {
        		$range = $self->sql_range ($where_hash->{$k});
        	}
            push @where, qq($qk in ($range));
            push @bind, @{$where_hash->{$k}};
        } else {
            push @where, qq($qk = ?);
            push @bind, $where_hash->{$k};
        }
    }
    
	return join (' and ', @where), \@bind;
}

# Получаем список выражений для SET 
# как строку вида 'param1 = ?, param2 = ?'
# и массив значений для bind,
# построенные на основе заданного хэша
sub sql_set {
	my $self = shift;
	my $param_hash = shift;
	my $where_hash = shift;
	
	unless (ref($param_hash) eq 'HASH') {
		warn "please specify parameters hash";
		return;
	}
	
	my @set;
	my @bind;
	
	for my $k (keys %$param_hash) {
		my $qk = $self->dbh->quote_identifier ($k);
		push @set, qq($qk = ?);
		push @bind, $param_hash->{$k};
	}
	
	my $sql_set = join ', ', @set;
	
	if (!defined $where_hash or ref($where_hash) !~ /HASH|ARRAY/) {
		return ($sql_set, \@bind);
	} else {
		my ($where_set, $bind_add) = $self->sql_where ($where_hash);
		@bind = (@bind, @$bind_add);
		return ($sql_set, \@bind, $where_set);
	}
}

# real sql statements

sub sql_insert {
	my $self = shift;
	my $hash = shift || $self->fields;
	
	my $fields = [keys %$hash]; 
	
	my $table_name = $self->table_quoted;
	
	my $placeholders = $self->sql_range ($fields);
	my $field_set = $self->sql_names_range ($fields);
	return "insert into $table_name ($field_set) values ($placeholders)",
		[map {$hash->{$_}} @$fields];
}

sub sql_update {
	my $self = shift;
	my $set_values = shift;
	my $where_values = shift;
	my $suffix = shift || '';
	
	my $table_name = $self->table_quoted;
	
	my ($set_statement, $bind, $where_statement)
		= $self->sql_set ($set_values, $where_values);
	
	my $statement = "update $table_name set $set_statement";
	$statement .= " where $where_statement"
		if $where_statement;
	return $statement . ' ' . $suffix, $bind;
}

sub sql_delete {
	my $self = shift;
	my $where_values = shift;
	my $suffix = shift || '';
	
	my $table_name = $self->table_quoted;
	
	my ($where_statement, $bind)
		= $self->sql_where ($where_values);
	
	my $statement = "delete from $table_name";
	if (!$where_statement) {
		warn "you can't delete all data from table, use delete_table_contents";
		return;
	}
	
	$statement .= " where $where_statement";
	debug $statement;
	return $statement . ' ' . $suffix, $bind;
}

sub sql_delete_by_pk {
	my $self   = shift;
	my $where  = shift || {};
	my $suffix = shift || '';
	
	my $pri_key_column = $self->pri_key_column;
	my $where_hash = {%$where, $pri_key_column => $self->{$self->pri_key}};
	
	return $self->sql_delete ($where_hash, $suffix);
	
}


sub sql_select_by_pk {
	my $self   = shift;
	my $where  = shift;
	my $suffix = shift || '';
	
	my $pri_key_column = $self->pri_key_column;
	$where = {%$where, $pri_key_column => $self->{$self->pri_key}};
	
	return $self->sql_select ($where, $suffix);
	
}

sub sql_update_by_pk {
	my $self   = shift;
	my $where  = shift || {};
	my $suffix = shift || '';
	
	my $set_hash = $self->fields_to_columns;
	my $pri_key_column = $self->pri_key_column;
	my $where_hash = {%$where, $pri_key_column => $self->{$self->pri_key}};
	
	my ($sql, $bind) = $self->sql_update ($set_hash, $where_hash, $suffix);
	
	return $sql, $bind;
	
}

sub sql_column_list {
	my $self = shift;
	my $fetch_fields = shift || $self->fetch_fields;
	
	return '*'
		if !defined $fetch_fields or !$fetch_fields;
	
	return $fetch_fields
		unless ref $fetch_fields;
	
	die "can't recognize what you want, provide arrayref or string as fetch fields"
		if ref $fetch_fields ne 'ARRAY' or ! scalar @$fetch_fields;
	
	my $col_list = [];
	
	my $fields = $self->fields;
	
	foreach my $field (@$fetch_fields) {
		if (exists $fields->{$field}) {
			push @$col_list, $fields->{$field}->{quoted_column_name};
		} else {
			# may be erratical
			push @$col_list, $field;
		}
	}
	
	return join ', ', @$col_list;
}

sub sql_select {
	my $self   = shift;
	my $where  = shift;
	my $suffix = shift || '';
	my $cols   = shift;
	
	my $cols_statement = $self->sql_column_list ($cols);
	
	my $table_name = $self->table_quoted;
	
	my $statement = "select $cols_statement from $table_name";
	
	if ($self->can ('join_table')) {
		my $join = $self->join_table;
		if (defined $join and $join !~ /^\s*$/) {
			$statement .= ' ' . $join;
		}
	}
	
	my ($where_statement, $bind);
	($where_statement, $bind) = $self->sql_where ($where);
	
	$statement .= " where $where_statement"
		if defined $where_statement and $where_statement !~ /^\s*$/;
	
	return
		join (' ', $statement, $suffix),
		$bind;
}

sub sql_select_count {
	my $self   = shift;
	my $where  = shift;
	my $suffix = shift || '';
	
	return $self->sql_select ($where, $suffix, 'count(*)');
	
}


1;