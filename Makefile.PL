use ExtUtils::MakeMaker;

WriteMakefile(
	NAME => "DBI::Easy",
	VERSION_FROM => "lib/DBI/Easy.pm",
	'dist' => { COMPRESS=>"gzip", SUFFIX=>"gz" },
	AUTHOR => 'Ivan Baktsheev <dot.and.thing@gmail.com>',
	PREREQ_PM => {
		'Class::Easy' => 0.02, # try_to_use support
		'DBI'         => 1.601,
		'DBD::SQLite' => 0,
	}
);
