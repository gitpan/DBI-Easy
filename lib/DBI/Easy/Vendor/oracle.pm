package DBI::Easy::Vendor::oracle;

use Class::Easy;

use base qw(DBI::Easy::Vendor::Base);

# alter session set nls_date_format='yyyy-mm-dd hh24:mi:ss';
# select to_char(some_date, 'yyyy-mm-dd hh24:mi:ss') my_date
#   from some_table;

# in the session, execute
# 
# SELECT value FROM nls_session_parameters WHERE parameter='NLS_DATE_FORMAT';

# In SQL*Plus, you can also use :
# 
# show parameter nls_date_format

sub vendor_schema {
	my $class = shift;
	
	return uc ($class->dbh->{Username});
}

sub _init_vendor {
	my $class = shift;
	$class->table_name (uc($class->table_name));
}

sub quote_identifier {
	my $class = shift;
	
	return shift;
}


1;