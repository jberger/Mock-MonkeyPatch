use strict;
use warnings;

use Test::More;
use Mock::MonkeyPatch;

my $called;
{
  package Local::Func;
  sub func { $called++; 'orig' }
}

my $orig = \&Local::Func::func;

subtest 'basic usage' => sub {
  my $mock = Mock::MonkeyPatch->patch(
    'Local::Func::func' => sub { 'mock' }
  );

  isnt \&Local::Func::func, $orig, 'mock was injected';

  is Local::Func::func(qw/a b c/), 'mock', 'got mocked value';
  is $mock->called, 1, 'mock was called';
  ok !$called, 'original function was not called';
  is_deeply $mock->arguments, [qw/a b c/], 'got the passed arguments';

  is Local::Func::func('x'), 'mock', 'got mocked value';
  is $mock->called, 2, 'mock was called again';
  ok !$called, 'original function was not called';
  is_deeply $mock->arguments(1), ['x'], 'got the new passed arguments';

  $mock->reset;
  ok !$mock->called, 'called is false after reset';
  ok !$mock->arguments(0), 'no arguments available after reset';

  $called = undef; # just in case
};

is \&Local::Func::func, $orig, 'mock was removed';

done_testing;

