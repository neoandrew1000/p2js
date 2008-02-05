#! /bin/false
# vim: set autoindent shiftwidth=4 tabstop=8:

package IWL::P2JS::IWL;

use strict;

=head1 NAME

IWL::P2JS::IWL - a plugin for P2JS to handle IWL specific tasks

=head1 DESCRIPTION

IWL::P2JS::IWL is a plugin, whose task is to overload specific L<IWL> functions, so that they use L<IWL::P2JS>.

=head1 CONSTRUCTOR

IWL::P2JS::IWL->new(B<IWL::P2JS>)

where B<IWL::P2JS> is an instantiated object from the L<IWL::P2JS> class

=cut

sub new {
    my ($proto, $converter) = @_;
    my $class = ref($proto) || $proto;
    my $self = bless {p2js => $converter}, $class;

    return $self->__inspectInc;
}

# Internal
#
my %monitors = qw(IWL/Script.pm 1 IWL/Widget.pm 1);
my %overridden;

sub __inspectInc {
    my $self = shift;
    do { $self->__connect($_) if $INC{$_} } foreach keys %monitors;

    BEGIN {
        *CORE::GLOBAL::require = sub {
            CORE::require($_[0]);
            $self->__connect($_[0]) if $self && $monitors{$_[0]};
            return 1;
        } unless $overridden{require};
    }
    $overridden{require} = 1;

    return $self;
}

sub __connect {
    my ($self, $filename) = @_;

    if ($filename eq 'IWL/Script.pm') {
        $self->__iwlScriptInit;
    } elsif ($filename eq 'IWL/Widget.pm') {
        $self->__iwlWidgetInit;
    }
    return $self;
}

# IWL::Script
#
no warnings qw(redefine);

sub __iwlScriptInit {
    my $self = shift;
    return if $overridden{"IWL::Script"};

    no strict 'refs';
    foreach my $method (qw(set append prepend)) {
        my $original = *{"IWL::Script::${method}Script"}{CODE};

        *{"IWL::Script::${method}Script"} = sub {
            my ($self_, $param) = @_;
            @_ = ($self_, ref $param eq 'CODE' ? $self->{p2js}->convert($param) : $param);

            goto $original;
        };
    }

    $overridden{"IWL::Script"} = 1;
}

# IWL::Widget
#
sub __iwlWidgetInit {
    my $self = shift;
    return if $overridden{"IWL::Widget"};

    no strict 'refs';
    foreach my $method (qw(Connect Disconnect)) {
        my $original = *{"IWL::Widget::signal${method}"}{CODE};

        *{"IWL::Widget::signal${method}"} = sub {
            my ($self_, $signal, $callback) = @_;
            my $globalScope = $self->{p2js}{_options}{globalScope};
            $self->{p2js}{_options}{globalScope} = 1;
            @_ = ($self_, $signal, ref $callback eq 'CODE' ? $self->{p2js}->convert($callback) : $callback);
            $self->{p2js}{_options}{globalScope} = $globalScope;

            goto $original;
        };
    }

    $overridden{"IWL::Widget"} = 1;
}

1;

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2007  Viktor Kojouharov. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See perldoc perlartistic.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
