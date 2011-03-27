package DBI::Easy::Vendor::Base;

use Class::Easy;

sub vendor_schema {
	return;
}

sub _init_vendor {

}

sub quote_identifier {
	my $class = shift;
	
	return $class->dbh->quote_identifier (@_);
}

1;

