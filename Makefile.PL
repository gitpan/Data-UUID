use ExtUtils::MakeMaker;
use Config;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'Data::UUID',
    'VERSION_FROM'	=> 'UUID.pm', # finds $VERSION
    'PREREQ_PM'		=> {}, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM => 'UUID.pm', # retrieve abstract from module
       AUTHOR     => 'A. U. Thor <a.u.thor@a.galaxy.far.far.away>') : ()),
    'LIBS'		=> ['-lsocket'], # e.g., '-lm'
    'DEFINE'		=> '', # e.g., '-DHAVE_SOMETHING'
	# Insert -I. if you add *.h files later:
    'INC'		=> '', # e.g., '-I/usr/include/other'
	# Un-comment this if you add C files to link with later:
    'OBJECT'		=> '$(O_FILES)', # link all the C files too
    'CONFIGURE'         => 
       sub {
          do { print "UUID state storage (/var/tmp): ";
          } while !($d = <STDIN>, chop $d, -d $d || !$d);
	  return { 'DEFINE' => qq(-D_STDIR=\\").($d||"/var/tmp").qq(\\").
		   qq( -D__$Config{osname}__)};
       }
);
