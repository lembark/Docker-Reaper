package Testify;
use Test::More;
use FindBin::libs;

my $madness = 'Docker::Reaper';

use_ok $madness;

can_ok $madness => 'VERSION';

ok $madness->VERSION;

done_testing
__END__
