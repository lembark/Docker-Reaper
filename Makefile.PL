use v5.24;
use ExtUtils::MakeMaker;

WriteMakefile
(
	NAME            => 'Docker::Reaper',
	VERSION_FROM	=> './lib/Docker/Reaper.pm', 
	ABSTRACT_FROM   => './lib/Docker/Reaper.pm', 

	PREREQ_PM =>
	{
		qw
		(
			Config			0
			FindBin::libs	0
			Symbol			0
		)
	},

);
