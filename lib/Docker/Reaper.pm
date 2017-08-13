########################################################################
# housekeeping
########################################################################

package Docker::Reaper v0.1.0;
use v5.24;

use Config;
use Symbol  qw( qualify_to_ref );

########################################################################
# package variables
########################################################################

my $verbose         = $ENV{ VERBOSE             } // '';
my $log_exits       = $ENV{ INIT_LOG_EXITS      } // $verbose;
my $debug_parent    = $ENV{ INIT_DEBUG_PARENT   } // '' ;

my $child           = '';

my @sigz
= grep
{
    index $_, 'CHLD' 
}
split $Config{ sig_name };

my $propagate
= sub
{
    my $sig = shift;

    say "Propagate signal: '$sig' to $child."
    if $verbose;

    kill( $sig, $child )
    ? $verbose && say 'Signal propagated' 
    : warn "Failed propagate: '$sig' to $child\n"
    ;

    return
};

########################################################################
# parent propagates signals, reaps, waits for child to exit.
# child exec's @ARGV.
########################################################################

sub init
{
    my $log_exits   = defined wantarray;

    $child   
    = $^P 
    ? $debug_parent 
    ? 2
    : 0
    : fork
    // die "Phorkafobia: $!\n";

    $child
    or do
    {
        @_
        ? exec @_
        : exec @ARGV
        ;

        die "Failed exec: $!\n"
    };
    
    # child never gets this far in the code via exec or die, above.
    #
    # parent waits for the child to exit, propagating any 
    # signals that can be and reaping any children.

    local @SIG{ @sigz } = ( $propagate ) x @sigz;

    my @exitz   = ();

    for(;;)
    {
        my $pid = wait;

        $pid > 0
        or die "Lost signal: $child exited.\n";

        $pid != $child 
        and do
        {
            say "Exit: $pid, $?"
            if $verbose;

            push @exitz, [ $pid, $? ]
            if $log_exits;
        };

        say "Child exit: $? ($child)";
        push @exitz, [ $child, $? ];

        last
    }

    wantarray
    ?  @exitz
    : \@exitz
}

sub import
{
    # discard the current package name.

    shift;

    # consume the stack.

    if
    (
        my ( $found ) = grep { ! index $_, ':log_exits=' } @_ 
    )
    {
        my ( undef, $arg ) = split '=' => $found, 2;

        $log_exits  = $arg // '';
    }
    
    if
    (
        my ( $found ) = grep { ! index $_, ':exec=' } @_
    )
    {
        # i.e., perform the fork/exec at begin time.
        #
        # Note: this will not return from import until
        # the child process has exited!

        my ( undef, $arg ) = split '=' => $found, 2;

        my $exitz
        = $arg
        ? init $arg
        : init @ARGV
        ;

        # i.e., propagate the child's exit value.

        exit $exitz->[-1][-1] >> 8;
    }
    else
    {
        my $caller  = caller;

        *{ qualify_to_ref init => $caller }  = \&init;
    }

    return
}

# keep require happy
1
__END__
