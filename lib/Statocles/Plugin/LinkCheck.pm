package Statocles::Plugin::LinkCheck;
# ABSTRACT: Check links and images for validity during build

use Statocles::Base 'Class';
with 'Statocles::Plugin';
use Mojo::DOM;
use Mojo::Util qw( url_escape url_unescape );

=attr ignore

An array of URL patterns to ignore. These are interpreted as regular expressions,
and are anchored to the beginning of the URL.

For example:

    /broken     will match "/broken.html" "/broken/page.html" but not "/page/broken"
    .*/broken   will match "/broken.html" "/broken/page.html" and "/page/broken"

=cut

has ignore => (
    is => 'ro',
    isa => ArrayRef[Str],
    default => sub { [] },
);

=method check_pages

    $plugin->check_pages( $event );

Check the pages inside the given
L<Statocles::Event::Pages|Statocles::Event::Pages> event.

=cut

sub check_pages {
    my ( $self, $event ) = @_;

    my %page_paths = ();
    my %links = ();
    for my $page ( @{ $event->pages } ) {
        $page_paths{ $page->path } = 1;
        if ( $page->DOES( 'Statocles::Page::Document' ) ) {
            my $dom = Mojo::DOM->new( $page->render( site => $event->emitter ) );

            for my $attr ( qw( src href ) ) {
                for my $el ( $dom->find( "[$attr]" )->each ) {
                    my $url = $el->attr( $attr );
                    $url =~ s{#.*$}{};
                    next unless $url;
                    next if $url =~ m{^(?:[a-z][a-z0-9+.-]*):}i;
                    next if $url =~ m{^//};
                    if ( $url !~ m{^/} ) {
                        $url = $page->path->parent->child( $url );
                    }
                    $links{ url_unescape $url }{ $page->path }++;

                }
            }
        }
    }

    for my $link_url ( keys %links ) {
        $link_url .= 'index.html' if $link_url =~ m{/$};
        next if $page_paths{ $link_url } || $page_paths{ "$link_url/index.html" };
        next if grep { $link_url =~ /^$_/ } @{ $self->ignore };
        for my $page_url ( keys %{ $links{ $link_url } } ) {
            $event->emitter->log->warn( "URL broken on $page_url: '$link_url' not found" );
        }
    }

}

=method register

Register this plugin to install its event handlers. Called automatically.

=cut

sub register {
    my ( $self, $site ) = @_;
    $site->on( build => sub { $self->check_pages( @_ ) } );
}

1;

=head1 SYNOPSIS

    # site.yml
    site:
        class: Statocles::Site
        args:
            plugins:
                link_check:
                    $class: Statocles::Plugin::LinkCheck

=head1 DESCRIPTION

This plugin checks all of the links and images to ensure they exist. If something
is missing, this plugin will write a warning to the screen.

