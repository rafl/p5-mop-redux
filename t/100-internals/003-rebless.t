#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use mop;

class Foo {
    has $!foo is rw = 'FOO';
}

class Bar {
    has $!bar is rw = 'BAR';
}

class Baz extends Foo {
    has $!baz is rw = 'BAZ';
}

class Quux extends Bar {
    has $!quux is rw = 'QUUX';
}

{
    my $foo_attr  = mop::meta('Foo')->get_attribute('$!foo');
    my $bar_attr  = mop::meta('Bar')->get_attribute('$!bar');
    my $baz_attr  = mop::meta('Baz')->get_attribute('$!baz');
    my $quux_attr = mop::meta('Quux')->get_attribute('$!quux');

    my $foo = Foo->new;
    is(${ $foo_attr->storage->{$foo} }, 'FOO');
    ok(!$bar_attr->storage->{$foo});
    ok(!$baz_attr->storage->{$foo});
    ok(!$quux_attr->storage->{$foo});

    mop::rebless $foo, 'Bar';
    ok(!$foo_attr->storage->{$foo});
    is(${ $bar_attr->storage->{$foo} }, 'BAR');
    ok(!$baz_attr->storage->{$foo});
    ok(!$quux_attr->storage->{$foo});

    mop::rebless $foo, 'Baz';
    is(${ $foo_attr->storage->{$foo} }, 'FOO');
    ok(!$bar_attr->storage->{$foo});
    is(${ $baz_attr->storage->{$foo} }, 'BAZ');
    ok(!$quux_attr->storage->{$foo});

    mop::rebless $foo, 'Quux';
    ok(!$foo_attr->storage->{$foo});
    is(${ $bar_attr->storage->{$foo} }, 'BAR');
    ok(!$baz_attr->storage->{$foo});
    is(${ $quux_attr->storage->{$foo} }, 'QUUX');
}

{
    my $foo = Foo->new;
    is($foo->foo, 'FOO');
    $foo->foo('abc');
    is($foo->foo, 'abc');

    mop::rebless $foo, 'Baz';
    is($foo->foo, 'abc');
    is($foo->baz, 'BAZ');

    mop::rebless $foo, 'Bar';
    ok(!$foo->can('foo'));
    ok(!$foo->can('baz'));
    is($foo->bar, 'BAR');

    mop::rebless $foo, 'Baz';
    is($foo->foo, 'FOO');
    is($foo->baz, 'BAZ');
}

done_testing;
