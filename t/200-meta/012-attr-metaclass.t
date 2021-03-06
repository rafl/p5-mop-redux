#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

use mop;

class MyAttribute extends mop::attribute { }

class Thingy {
	has $!doodah meta MyAttribute;
}

isa_ok(
	mop::meta('Thingy')->get_attribute('$!doodah'),
	$_,
	q[mop::meta('Thingy')->get_attribute('$!doodah')]
) for qw( mop::attribute MyAttribute );

done_testing;
