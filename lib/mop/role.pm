package mop::role;

use v5.16;
use warnings;

use mop::internals::util;

use Module::Runtime qw[ is_module_name module_notional_filename ];

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

use parent 'mop::object', 'mop::internals::observable';

mop::internals::util::init_attribute_storage(my %name);
mop::internals::util::init_attribute_storage(my %version);
mop::internals::util::init_attribute_storage(my %authority);

mop::internals::util::init_attribute_storage(my %roles);
mop::internals::util::init_attribute_storage(my %attributes);
mop::internals::util::init_attribute_storage(my %methods);
mop::internals::util::init_attribute_storage(my %required_methods);

# temporary, for bootstrapping
sub new {
    my $class = shift;
    my %args  = @_;

    my $self = $class->SUPER::new( @_ );

    $name{ $self }       = \($args{'name'});
    $version{ $self }    = \($args{'version'});
    $authority{ $self }  = \($args{'authority'});

    $roles{ $self }            = \($args{'roles'} || []);
    $attributes{ $self }       = \({});
    $methods{ $self }          = \({});
    $required_methods{ $self } = \({});

    $self;
}

sub BUILD {
    my $self = shift;

    mop::internals::util::install_meta($self);

    if (my @nometa = grep { !mop::meta($_) } @{ $self->roles }) {
        die "No metaclass found for these roles: @nometa";
    }

    if ( defined($self->name) && is_module_name($self->name) ) {
        $INC{ module_notional_filename($self->name) } //= '(mop)';
    }
}

sub clone {
    my $self = shift;
    my (%args) = @_;

    die "You must specify a name when cloning a metaclass"
        unless $args{name};

    my $methods = $self->method_map;
    $args{methods} //= {
        map { $_ => $methods->{$_}->clone } keys %$methods
    };

    my $attributes = $self->attribute_map;
    $args{attributes} //= {
        map { $_ => $attributes->{$_}->clone } keys %$attributes
    };

    my $clone = $self->SUPER::clone(%args);

    for my $method (keys %{ $args{methods} }) {
        $clone->get_method($method)->set_associated_meta($clone);
    }

    for my $attribute (keys %{ $args{attributes} }) {
        $clone->get_attribute($attribute)->set_associated_meta($clone);
    }

    return $clone;
}

# identity

sub name       { ${ $name{ $_[0] } // \undef } }
sub version    { ${ $version{ $_[0] } // \undef } }
sub authority  { ${ $authority{ $_[0] } // \undef } }

# roles

sub roles { ${ $roles{ $_[0] } } }

sub add_role {
    my ($self, $role) = @_;
    push @{ $self->roles } => $role;
}

sub does_role {
    my ($self, $name) = @_;
    foreach my $role ( @{ $self->roles } ) {
        return 1 if $role->name eq $name
                 || $role->does_role( $name );
    }
    return 0;
}

# attributes

sub attribute_class { 'mop::attribute' }

sub attribute_map { ${ $attributes{ $_[0] } } }

sub attributes { values %{ $_[0]->attribute_map } }

sub add_attribute {
    my ($self, $attr) = @_;
    $self->attribute_map->{ $attr->name } = $attr;
    $attr->set_associated_meta($self);
}

sub get_attribute {
    my ($self, $name) = @_;
    $self->attribute_map->{ $name }
}

sub has_attribute {
    my ($self, $name) = @_;
    exists $self->attribute_map->{ $name };
}

# methods

sub method_class { 'mop::method' }

sub method_map { ${ $methods{ $_[0] } } }

sub methods { values %{ $_[0]->method_map } }

sub add_method {
    my ($self, $method) = @_;
    $self->method_map->{ $method->name } = $method;
    $method->set_associated_meta($self);
    $self->remove_required_method($method->name);
}

sub get_method {
    my ($self, $name) = @_;
    $self->method_map->{ $name }
}

sub has_method {
    my ($self, $name) = @_;
    exists $self->method_map->{ $name };
}

# required methods

sub required_method_map { ${ $required_methods{ $_[0] } } }

sub required_methods { keys %{ $_[0]->required_method_map } }

sub add_required_method {
    my ($self, $name) = @_;
    $self->required_method_map->{ $name } = 1;
}

sub remove_required_method {
    my ($self, $name) = @_;
    delete $self->required_method_map->{ $name };
}

sub requires_method {
    my ($self, $name) = @_;
    defined $self->required_method_map->{ $name };
}

# events

sub FINALIZE {
    my $self = shift;
    mop::internals::util::finalize_meta($self);
}

our $METACLASS;

sub __INIT_METACLASS__ {
    return $METACLASS if defined $METACLASS;
    require mop::class;
    $METACLASS = mop::class->new(
        name       => 'mop::role',
        version    => $VERSION,
        authority  => $AUTHORITY,
        superclass => 'mop::object'
    );

    $METACLASS->add_attribute(mop::attribute->new(
        name    => '$!name',
        storage => \%name,
        default => \(sub { die "name is required when creating a role or class" }),
    ));

    $METACLASS->add_attribute(mop::attribute->new(
        name    => '$!version',
        storage => \%version
    ));

    $METACLASS->add_attribute(mop::attribute->new(
        name    => '$!authority',
        storage => \%authority
    ));

    $METACLASS->add_attribute(mop::attribute->new(
        name    => '$!roles',
        storage => \%roles,
        default => \sub { [] },
    ));

    $METACLASS->add_attribute(mop::attribute->new(
        name    => '$!attributes',
        storage => \%attributes,
        default => \sub { {} },
    ));

    $METACLASS->add_attribute(mop::attribute->new(
        name    => '$!methods',
        storage => \%methods,
        default => \sub { {} },
    ));

    $METACLASS->add_attribute(mop::attribute->new(
        name    => '$!required_methods',
        storage => \%required_methods,
        default => \sub { {} },
    ));

    $METACLASS->add_method( mop::method->new( name => 'BUILD', body => \&BUILD ) );

    $METACLASS->add_method( mop::method->new( name => 'clone', body => \&clone ) );

    $METACLASS->add_method( mop::method->new( name => 'name',       body => \&name       ) );
    $METACLASS->add_method( mop::method->new( name => 'version',    body => \&version    ) );
    $METACLASS->add_method( mop::method->new( name => 'authority',  body => \&authority  ) );

    $METACLASS->add_method( mop::method->new( name => 'roles',     body => \&roles     ) );
    $METACLASS->add_method( mop::method->new( name => 'add_role',  body => \&add_role  ) );
    $METACLASS->add_method( mop::method->new( name => 'does_role', body => \&does_role ) );

    $METACLASS->add_method( mop::method->new( name => 'attribute_class', body => \&attribute_class ) );
    $METACLASS->add_method( mop::method->new( name => 'attribute_map',   body => \&attribute_map   ) );
    $METACLASS->add_method( mop::method->new( name => 'attributes',      body => \&attributes      ) );
    $METACLASS->add_method( mop::method->new( name => 'get_attribute',   body => \&get_attribute   ) );
    $METACLASS->add_method( mop::method->new( name => 'add_attribute',   body => \&add_attribute   ) );
    $METACLASS->add_method( mop::method->new( name => 'has_attribute',   body => \&has_attribute   ) );

    $METACLASS->add_method( mop::method->new( name => 'method_class',  body => \&method_class  ) );
    $METACLASS->add_method( mop::method->new( name => 'method_map',    body => \&method_map    ) );
    $METACLASS->add_method( mop::method->new( name => 'methods',       body => \&methods       ) );
    $METACLASS->add_method( mop::method->new( name => 'get_method',    body => \&get_method    ) );
    $METACLASS->add_method( mop::method->new( name => 'add_method',    body => \&add_method    ) );
    $METACLASS->add_method( mop::method->new( name => 'has_method',    body => \&has_method    ) );

    $METACLASS->add_method( mop::method->new( name => 'required_methods',    body => \&required_methods    ) );
    $METACLASS->add_method( mop::method->new( name => 'required_method_map', body => \&required_method_map ) );
    $METACLASS->add_method( mop::method->new( name => 'add_required_method', body => \&add_required_method ) );
    $METACLASS->add_method( mop::method->new( name => 'remove_required_method', body => \&remove_required_method ) );
    $METACLASS->add_method( mop::method->new( name => 'requires_method',     body => \&requires_method     ) );


    $METACLASS->add_method( mop::method->new( name => 'FINALIZE', body => \&FINALIZE ) );

    $METACLASS;
}

1;

__END__

=pod

=head1 NAME

mop::role

=head1 DESCRIPTION

=head1 BUGS

All complex software has bugs lurking in it, and this module is no
exception. If you find a bug please either email me, or add the bug
to cpan-RT.

=head1 AUTHOR

Stevan Little <stevan@iinteractive.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Infinity Interactive.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut




