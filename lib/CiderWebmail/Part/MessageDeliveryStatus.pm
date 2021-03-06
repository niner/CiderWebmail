package CiderWebmail::Part::MessageDeliveryStatus;

use Moose;
use Petal;

use Regexp::Common qw /URI/;
use HTML::Entities;

use Carp qw/ croak carp /;

extends 'CiderWebmail::Part';
has renderable          => (is => 'rw', isa => 'Bool', default => 1 );
has render_as_stub      => (is => 'rw', isa => 'Bool', default => 0 );
has message             => (is => 'rw', isa => 'Bool', default => 0 );

=head2 render()

Internal method rendering a message/delivery-status body part.

=cut

sub render {
    my ($self) = @_;

    carp('no part set') unless defined $self->body;

    my $content = $self->body;

    $content =~ s/[^\x01-\x{D7FF}\x{E000}-\x{FFFD}\x{10000}-\x{10FFFF}]//gxmo;
    $content =~ s/[\x01-\x08\x0B-\x0C\x0E-\x1F\x7F-\x84\x86-\x9F]//gxmo;

    HTML::Entities::encode($content, '<>&"');

    $content =~ s/\n/<br \/>/xmg;
    
    return $self->c->view->render_template({ c => $self->c, template => 'TextPlain.xml', stash => { part_content => $content } });
}

=head2 supported_type()

returns the content type this plugin can handle

=cut

sub supported_type {
    return 'message/delivery-status';
}

1;
