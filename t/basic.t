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
};

is \&Local::Func::func, $orig, 'mock was removed (DESTROY)';

subtest 'store arguments' => sub {
  my $mock = Mock::MonkeyPatch->patch(
    'Local::Func::func' => sub { 'mock' }, { store_arguments => 0 }
  );
  is $mock->store_arguments, 0, 'constructor arg';

  Local::Func::func(qw/a b c/);
  is $mock->called, 1, 'mock was called';
  ok !$mock->arguments, 'passed arguments not stored';

  $mock->store_arguments(1);
  Local::Func::func(qw/d e f/);
  is $mock->called, 2, 'mock was called';
  is_deeply $mock->arguments(1), [qw/d e f/], 'got the passed arguments';

  $mock->store_arguments(0);
  Local::Func::func(qw/g h i/);
  is $mock->called, 3, 'mock was called';
  ok !$mock->arguments(2), 'passed arguments not stored';

  $mock->restore;
  is \&Local::Func::func, $orig, 'mock was removed';
};

subtest 'only restore once' => sub {
  my $mock = Mock::MonkeyPatch->patch(
    'Local::Func::func' => sub { 'mock' }
  );
  
  isnt \&Local::Func::func, $orig, 'mock was injected';
  $mock->restore;
  is \&Local::Func::func, $orig, 'mock was removed';

  my $other = Mock::MonkeyPatch->patch(
    'Local::Func::func' => sub { 'other' }
  );

  my $new = \&Local::Func::func;
  isnt $new, $orig, 'new mock was injected';
  $mock->restore;
  is \&Local::Func::func, $new, 'new mock is still in place';
  isnt \&Local::Func::func, $orig, 'new mock was not removed';
};

done_testing;

