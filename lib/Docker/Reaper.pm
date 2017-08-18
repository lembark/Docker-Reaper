########################################################################
# housekeeping
########################################################################

package Docker::Reaper v0.1.0;
use v5.24;

use Config;

use Carp    qw( croak           );
use Symbol  qw( qualify_to_ref  );

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
    'CHLD' ne $_
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
# utility subs
########################################################################

my $format_exit
= sub
{
    my ( $pid, $status ) = @_;

    my $exit    = $status >> 8;
    my $core    = $status &  128;
    my $signum  = $status & 0x0F;

    my $message = "PID $pid exit( $exit )";
    $message    .= ' with core'         if $core;
    $message    .= " killed by $signum" if $signum;

    $message
};

my $log_exit_stack
= sub
{

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
        : @ARGV
        ? exec @ARGV
        : croak 'Bogus init: both @_ and @ARGV are empty.'
        ;

        die "Failed exec: $!\n"
    };
    
    # child never gets this far in the code via exec or die, above.
    #
    # parent waits for the child to exit, propagating any 
    # trap-able signals and reaping any children.

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

            next
        };

        say "Child exit: $? ($child)";
        push @exitz, [ $child, $? ];

        if( $verbose )
        {
            say $format_exit->( @$_ )
            for @exitz;
        }

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

    my $init_exits
    = do
    {
        if
        (
            my ( $found ) = grep { ! index $_, ':exit=' } @_ 
        )
        {
            my ( undef, $arg ) = split '=' => $found, 2;

            $arg // ''
        }
        else
        {
            ''
        }
    };
    
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
        : @ARGV
        ? init @ARGV
        : croak 'Bogus Docker::Reaper: both ":exec=" argument & @ARGV empty';
        ;

        # i.e., propagate the child's exit value.

        exit $exitz->[-1][-1] >> 8
        if $init_exits;
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

=head1 NAME

Docker::Reaper - Init-ish function to reap children.

=head1 SYNOSIS

    # import 'init' sub
    # perform any setup.
    # run init to fork-exec the program with arguments, wait
    # for it to exit, reaping defunct proc's. this will also
    # propagate any trapable signals to the child process.

    use Docker::Reaper;

    init qw( /path/to/program arg arg ... );

    # immediately exec the program at BEGIN time when the 
    # module is used, optionally with arguments.
    #
    # note that this will fork-exec the program from a call
    # in Docker::Reaper::import, the use will *not* return 
    # until the child process has exited. this basically turns
    # the remainder of any code into cleanup for the exec'd
    # program.

    use Docker::Reaper qw( :exec=/path/to/program );

    use Docker::Reaper ':exec=/path/to/program arg arg ...';

    # false value to exec uses @ARGV.

    use Docker::Reaper qw( :exec= );


    # turn on logging of exit status to stdout for all exiting
    # procs, not just the child.

    use Docker::Reaper qw( ":log_exits=1" );

    # turn off loggin of exits even if INIT_LOG_EXITS is set
    # in the environment.

    use Docker::Reaper qw( ":log_exits=0" );


    # turn on verbose logging in init, this sets INIT_LOG_EXITS.

    export VERBOSE=1;

    # turn on logging of exits.

    export INIT_LOG_EXITS=1;


