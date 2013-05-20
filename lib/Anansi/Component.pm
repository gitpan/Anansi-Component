package Anansi::Component;


=head1 NAME

Anansi::Component - A base module definition for related processes that are managed.

=head1 SYNOPSIS

 package Anansi::ComponentManagerExample::ComponentExample;

 use base qw(Anansi::Component);

 sub validate {
  return 1;
 }

 sub doSomething {
     my ($self, $channel, %parameters) = @_;
 }

 Anansi::Component::addChannel('Anansi::ComponentManagerExample::ComponentExample', 'VALIDATE_AS_APPROPRIATE' => Anansi::ComponentManagerExample::ComponentExample->validate);
 Anansi::Component::addChannel('Anansi::ComponentManagerExample::ComponentExample', 'SOME_COMPONENT_CHANNEL' => Anansi::ComponentManagerExample::ComponentExample->doSomething);

 1;

 package Anansi::ComponentManagerExample;

 use base qw(Anansi::ComponentManager);

 sub doSomethingElse {
     my ($self, $channel, %parameters) = @_;
 }

 Anansi::ComponentManager::addChannel('Anansi::ComponentManagerExample', 'SOME_MANAGER_CHANNEL' => Anansi::ComponentManagerExample->doSomethingElse);

 1;

=head1 DESCRIPTION

This is a base module definition for related functionality modules.  This module
provides the mechanism to be handled by a management module.  In order to
simplify the recognition and management of related "component" modules, each
component is required to have the same base namespace as it's manager.

=cut


our $VERSION = '0.01';

use base qw(Anansi::Class);

use Anansi::Actor;


my %CHANNELS;


=head1 METHODS

=cut


=head2 addChannel

 if(1 == Anansi::Component->addChannel(
  someChannel => 'Some::subroutine',
  anotherChannel => Some::subroutine,
  yetAnotherChannel => $AN_OBJECT->someSubroutine,
  etcChannel => sub {
   my $self = shift(@_);
  }
 ));

 # OR

 if(1 == $OBJECT->addChannel(
  someChannel => 'Some::subroutine',
  anotherChannel => Some::subroutine,
  yetAnotherChannel => $AN_OBJECT->someSubroutine,
  etcChannel => sub {
   my $self = shift(@_);
  }
 ));

Defines the responding subroutine for the named component channels.

=cut


sub addChannel {
    my ($self, %parameters) = @_;
    my $package = $self;
    $package = ref($self) if(ref($self) !~ /^$/);
    return 0 if(0 == scalar(keys(%parameters)));
    foreach my $key (keys(%parameters)) {
        if(ref($key) !~ /^$/) {
            return 0;
        } elsif(ref($parameters{$key}) =~ /^CODE$/i) {
        } elsif(ref($parameters{$key}) !~ /^$/) {
            return 0;
        } elsif($parameters{$key} =~ /^[a-zA-Z]+[a-zA-Z0-9_]*(::[a-zA-Z]+[a-zA-Z0-9_]*)*$/) {
            if(exists(&{$parameters{$key}})) {
            } elsif(exists(&{$package.'::'.$parameters{$key}})) {
            } else {
                return 0;
            }
        } else {
            return 0;
        }
    }
    $CHANNELS{$package} = {} if(!defined($CHANNELS{$package}));
    foreach my $key (keys(%parameters)) {
        if(ref($parameters{$key}) =~ /^CODE$/i) {
            %{$CHANNELS{$package}}->{$key} = sub {
                my ($self, $channel, @PARAMETERS) = @_;
                return &{$parameters{$key}}($self, $channel, (@PARAMETERS));
            };
        } elsif($parameters{$key} =~ /^[a-zA-Z]+[a-zA-Z0-9_]*(::[a-zA-Z]+[a-zA-Z0-9_]*)*$/) {
            if(exists(&{$parameters{$key}})) {
                %{$CHANNELS{$package}}->{$key} = sub {
                    my ($self, $channel, @PARAMETERS) = @_;
                    return &{\&{$parameters{$key}}}($self, $channel, (@PARAMETERS));
                };
            } else {
                %{$CHANNELS{$package}}->{$key} = sub {
                    my ($self, $channel, @PARAMETERS) = @_;
                    return &{\&{$package.'::'.$parameters{$key}}}($self, $channel, (@PARAMETERS));
                };
            }
        }
    }
    return 1;
}


=head2 channel

 Anansi::Component->channel('Anansi::Component::Example');

 # OR

 $OBJECT->channel();

 # OR

 Anansi::Component->channel('Anansi::Component::Example', 'someChannel', someParameter => 'something');

 # OR

 $OBJECT->channel('someChannel', someParameter => 'something');

Either returns an ARRAY of the available channels or passes the supplied
parameters to the named channel.  Returns UNDEF on error.

=cut


sub channel {
    my $self = shift(@_);
    $self = shift(@_) if('Anansi::Component' eq $self);
    my $package = $self;
    $package = ref($self) if(ref($self) !~ /^$/);
    if(0 == scalar(@_)) {
        return [] if(!defined($CHANNELS{$package}));
        return [( keys(%{$CHANNELS{$package}}) )];
    }
    my ($channel, @parameters) = @_;
    return if(ref($channel) !~ /^$/);
    return if(!defined($CHANNELS{$package}));
    return if(!defined(%{$CHANNELS{$package}}->{$channel}));
    return &{%{$CHANNELS{$package}}->{$channel}}($self, $channel, (@parameters));
}


=head2 componentManagers

 my $managers = Anansi::Component->componentManagers();

 # OR

 my $managers = Anansi::Component::componentManagers('Anansi::ComponentManagerExample::ComponentExample');

 # OR

 my $managers = $OBJECT->componentManagers();

Either returns an ARRAY of all of the available component managers or an ARRAY
containing the current component's manager.

=cut


sub componentManagers {
    my ($self, %parameters) = @_;
    my $package = $self;
    $package = ref($package) if(ref($package) !~ /^$/);
    if('Anansi::Component' eq $package) {
        my %modules = Anansi::Actor->modules();
        my @managers;
        foreach my $module (keys(%modules)) {
            next if('Anansi::ComponentManager' eq $module);
            require $modules{$module};
            next if(!eval { $module->isa('Anansi::ComponentManager') });
            push(@managers, $module);
        }
        return [(@managers)];
    }
    my @namespaces = split(/::/, $package);
    return [] if(scalar(@namespaces) < 2);
    pop(@namespaces);
    my $namespace = join('::', @namespaces);
    my $filename = join('/', @namespaces).'.pm';
    require $filename;
    return [] if(!eval { $namespace->isa('Anansi::ComponentManager') });
    return [$namespace];
}


=head2 removeChannel

 if(1 == Anansi::Component::removeChannel('Anansi::ComponentManagerExample::ComponentExample', 'someChannel', 'anotherChannel', 'yetAnotherChannel', 'etcChannel'));

 # OR

 if(1 == $OBJECT->removeChannel('someChannel', 'anotherChannel', 'yetAnotherChannel', 'etcChannel'));

Undefines the responding subroutine for the named component channels.

=cut


sub removeChannel {
    my ($self, @parameters) = @_;
    my $package = $self;
    $package = ref($self) if(ref($self) !~ /^$/);
    return 0 if(0 == scalar(@parameters));
    return 0 if(!defined($CHANNELS{$package}));
    foreach my $key (@parameters) {
        return 0 if(!defined(%{$CHANNELS{$package}}->{$key}));
    }
    foreach my $key (@parameters) {
        delete %{$CHANNELS{$package}}->{$key};
    }
    return 1;
}


=head1 AUTHOR

Kevin Treleaven <kevin AT treleaven DOT net>

=cut


1;
