package Mock::MonkeyPatch;

sub _defined { defined &{$_[0]} }
sub _patch { *{$_[0]} = $_[1] }

use strict;
use warnings;

use Carp ();
use Scalar::Util ();

sub ORIGINAL;

sub arguments {
  my ($self, $occurance) = @_;
  return $self->{arguments}[$occurance // 0];
}

sub method_arguments {
  my ($self, $occurance, $type) = @_;
  return undef
    unless my $args = $self->arguments($occurance);
  my @args = @$args; # copy
  my $inst = shift @args;
  if ($type) {
    return undef
      unless $inst->isa($type);
  }
  return \@args;
}

sub called { scalar @{$_[0]{arguments}} }

sub patch {
  my ($class, $symbol, $sub, $opts) = @_;
  $opts ||= {};

  $symbol =~ s/^&//;

  Carp::croak "Symbol &$symbol is not already defined"
    unless _defined $symbol;

  my $self = bless {
    arguments => [],
    original => \&{$symbol},
    store => exists $opts->{store_arguments} ? $opts->{store_arguments} : 1,
    sub => $sub,
    symbol => $symbol,
  }, $class;

  Scalar::Util::weaken(my $weak = $self);
  _patch $symbol => sub {
    local *ORIGINAL = $weak->{original};
    push @{ $weak->{arguments} }, [ $weak->{store} ? @_ : () ];
    $sub->(@_);
  };

  return $self;
}

sub reset { $_[0]{arguments} = []; $_[0] }

sub restore {
  my $self = shift;
  if (my $orig = delete $self->{original}) {
    _patch $self->{symbol}, $orig;
  }
  return $self;
}

sub store_arguments { @_ == 1 ? $_[0]{store} : do { $_[0]{store} = $_[1]; $_[0] } }

sub DESTROY {
  my $self = shift;
  return if defined ${^GLOBAL_PHASE} && ${^GLOBAL_PHASE} eq 'DESTRUCT';
  $self->restore;
}

1;

=head1 NAME

Mock::MonkeyPatch - Monkey patching with test mocking in mind

=head1 SYNOPSIS

  {
    package MyApp;

    sub gen_item_id {
      my $type = shift;
      # calls external service and gets id for $type
    }

    sub build_item {
      my $type = shift;
      my $item = Item->new(type => $type);
      $item->id(gen_item_id($type));
      return $item;
    }
  }

  use Test::More;
  use MyApp;
  use Mock::MonkeyPatch;

  my $mock = Mock::MonkeyPatch->patch(
    'MyApp::gen_item_id' => sub { 'abcd' }
  );

  my $item = MyApp::build_item('rubber_chicken');
  is $item->id, 'abcd', 'building item calls MyApp::gen_random_id';
  ok $mock->called, 'the mock was indeed called';
  is_deeply $mock->arguments(0), ['rubber_chicken'], 'the mock was called with expected arguments';

=head1 COOKBOOK

=head2 Run code before the original

  my $mock = $self->patch($symbol, sub {
    $sub->(@_);
    Mock::MonkeyPatch::ORIGINAL(@_);
  });

=head1 SOURCE REPOSITORY

L<http://github.com/jberger/Mock-MonkeyPatch>

=head1 AUTHOR

Joel Berger, E<lt>joel.a.berger@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2016 by Joel Berger

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
