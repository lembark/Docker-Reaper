# Docker::FakeInit - Clean up child processes like init would
# Copyright (C) 2017 Steven Pritchard <steve@silug.org>
#
# Based on an idea by Steven Lembark.
#
# This program is free software; you can redistribute it
# and/or modify it under the same terms as Perl itself.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

package Docker::Init v0.01;
use v5.24;

use Carp;
use IO::Handle;

use POSIX qw(pause :sys_wait_h);

our $VERSION=0.01;

INIT {
    my $break=0;
    my $exitstatus=0;

    my $child=fork();

    if (!defined($child)) {
        # fork() failed
        carp "fork() failed: $!. Not setting up SIGCHLD handler.";
    } elsif ($child == 0) {
        # In the child.
    } else {
        # In the parent
        sub interrupt {
            $break=shift;
        }

        my @signals=qw(HUP INT QUIT USR1 USR2 PIPE TERM TSTP TTIN TTOU WINCH);
        for my $signal (@signals) {
            $SIG{$signal}=\&interrupt;
        }
        $SIG{'CHLD'}=$SIG{'ALRM'}=sub { $break=0 };

        while (kill(0, $child)) {
            # Child is still alive
            alarm(10); # Wake up every 10 seconds to check for zombies
            pause; # Wait for a signal
            kill($break, $child) if ($break); # Pass HUP/INT/QUIT/TERM on to child

            # Reap any dead children
            my $pid;
            do { $pid=waitpid(-1, WNOHANG); } while ($pid > 0);

            if ($pid == $child) {
                $exitstatus=$?;
                exit $exitstatus;
            }
        }
        exit $exitstatus;
    }
}

1;
__END__

=head1 NAME

Docker::FakeInit - Clean up child processes like init would

=head1 SYNOPSIS

  use Docker::FakeInit;

=head1 DESCRIPTION

Since the entrypoint for Docker containers runs as PID 1, your script needs to reap
children the way that init would, otherwise you will end up with zombie
processes inside your container.  This module forks (so that your code runs
unmodified), then sets up signal handlers to catch SIGCHLD or pass the signals
through to the original script as appropriate.  When your script exits, the fake
init process exits.

=head1 AUTHOR

Steven Pritchard <steve@silug.org>

=head1 SEE ALSO

init(1), docker(1).

=cut
