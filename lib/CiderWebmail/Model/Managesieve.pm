package CiderWebmail::Model::Managesieve;
use Moose;
use namespace::autoclean;

use Net::ManageSieve;

use Carp qw(carp croak confess);
use Encode;

extends 'Catalyst::Model';

has '_managesieve' => (is => 'rw', isa => 'Object');
has 'username' => (is => 'rw', isa => 'Str');

sub login {
    my ($self, $o) = @_;

    croak 'Need username to attempt managesieve login' unless $o->{username};
    croak 'Need password to attempt managesieve login' unless $o->{password};

    #TODO error handling after errorhandling branch merge
    $self->_managesieve(Net::ManageSieve->new($self->config->{host}, Port => $self->config->{port}, on_fail => 'die' ));

    $self->_managesieve->login($o->{username}, $o->{password});
}

sub list_scripts {
    my ($self) = @_;

    #the complete list of scripts from the managesieve server
    #the last script in this list (which might be empty) is the currently active script
    my @list_scripts_response = @{ $self->_managesieve->listscripts };

    my $active_script = pop(@list_scripts_response);
    my %sieve_scripts = map { $_ => ( $_ eq $active_script ? 1 : 0 ) } @list_scripts_response;

    return \%sieve_scripts;
}

sub script_exists {
    my ($self, $o) = @_;

    croak 'Need script name to check if it exists.' unless $o->{name};

    return defined $self->list_scripts->{$o->{name}};
}

sub active_script {
    my ($self, $o) = @_;

    #set script active if a script name was given
    if (defined $o->{name}) {
        $self->_managesieve->setactive($o->{name}) if defined $o->{name};
    }

    my $scripts = $self->_managesieve->listscripts;
    return pop(@$scripts); #last script in array is the active script
}

sub disable_script {
    my ($self, $o) = @_;

    croak 'Need script name to disable script.' unless $o->{name};

    if ($self->active_script eq $o->{name}) {
        $self->_managesieve->setactive("");
    }
}

sub delete_script {
    my ($self, $o) = @_;

    $self->disable_script($o);
    $self->_managesieve->deletescript($self->_encode_string($o->{name}));
}

sub put_script {
    my ($self, $o) = @_;

    croak 'Need script name to put script.' unless $o->{name};
    croak 'Need script content to put script.' unless $o->{content};

    #TODO validate with Net::Sieve::Script
    $self->_managesieve->putscript($o->{name}, $o->{content});
}

sub get_script {
    my ($self, $o) = @_;

    croak 'Need script name to get script.' unless $o->{name};

    return $self->_managesieve->getscript($o->{name});
}

sub rename_script {
    my ($self, $o) = @_;

    croak 'Need old script name to rename script.' unless $o->{old_name};
    croak 'Need new script name to rename script.' unless $o->{new_name};

    my $source_script_was_active = 0;
    if ($o->{old_name} eq $self->active_script) {
        $self->_managesieve->setactive("");
        $source_script_was_active = 1;
    }

    $self->put_script({
        name    => $o->{new_name},
        content => $self->get_script({ name => $o->{old_name} }),
    });

    $self->_managesieve->deletescript($o->{old_name});

    $self->_managesieve->setactive($o->{new_name}) if $source_script_was_active;

    return;
}

sub _encode_string {
    my ($self, $string) = @_;

    $string = Encode::encode("utf8", $string);
    $string = Encode::encode("utf8", $string);

    return $string;
}

sub build_vacation_script {
    my ($self, $o) = @_;

    croak 'Need subject to build vacation script.' unless $o->{subject};
    croak 'Need reply text to build vacation script.' unless $o->{text};

    #TODO proper quoting?
    $o->{subject} =~ s/[\n\"]//g;
    $o->{text} =~ s/[\n\"]//g;

    my $vacation_script = qq|#CiderWebmail Vacation Rule v1\n|;
    $vacation_script   .= qq|#DO NOT MANUALLY EDIT THIS\n|;
    $vacation_script   .= qq|require ["vacation"];\n|;
    $vacation_script   .= qq|if not header :contains "Precedence" ["bulk","list"] {\n|;
    $vacation_script   .= qq|    vacation :days 7 :subject "$o->{subject}" "$o->{text}";\n|;
    $vacation_script   .= qq|}\n|;

    return $vacation_script;
}


=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
