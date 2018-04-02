use strict;
use warnings;
use Test::More;
use Test::WWW::Mechanize::Catalyst;
use utf8;

my $mc = Test::WWW::Mechanize::Catalyst->new(catalyst_app => 'Roseno');

$mc->get_ok('/');

$mc->get_ok('/iniciativas');
$mc->title_like( qr/iniciativas/i );
$mc->content_contains('iniciativas');

# Auth will be denied. User will be redirected to login page
$mc->get_ok('/iniciativas/adicionar');
$mc->title_like( qr/Login/ );
$mc->content_contains( 'Entre com seus dados' );

# Login error
$mc->submit_form(
    form_number => 3,
    fields => { username => 'wrong', password => 'wrong' }
);

$mc->title_like( qr/Login/ );
$mc->content_contains( 'Entre com seus dados' );

# Good login
$mc->submit_form_ok({
    form_number => 3,
    fields => { username => 'test_user', password => 'test_user' }
}, 'Logando');

like( $mc->uri, qr{.*iniciativas/adicionar$} );

# Form error
$mc->submit_form_ok({
    form_number => 3,
    fields => { id => 'non_existent_field' }
}, 'campo que não existe');

like( $mc->uri, qr{.*iniciativas/adicionar$}, 'Estamos em "iniciativas/adicionar"' );

# Good form
my $id;
$id .= int rand 9 for 1..5;

$mc->submit_form_ok({
    with_fields => {
        id => $id,
        title => "title$id",
        subtitle => "subtitle$id",
        body => "body$id",
        published => '21/02/2019 14:30',
        image => [['t/smile.png', 'the_smile.png'],1],
    },
    button => 'submit_edit',
}, 'Adicionando iniciativa');

like( $mc->uri, qr/$id/ );

$mc->get_ok('/iniciativas/' . $id . '/editar');

$mc->submit_form_ok({
    with_fields => {
        title => "titletitle$id",
    },
});

$mc->get_ok('/iniciativas/' . $id . '/deletar');
$mc->content_contains( 'deleção' );

$mc->submit_form_ok({
    with_fields => {
        'delete-confirmation' => "wrong_word",
    },
});

$mc->content_contains( 'Houve um problema na submissão do formulário' );

$mc->submit_form_ok({
    with_fields => { 'delete-confirmation' => 'wrong' },
    button => 'submit_cancel',
}, 'Cancel button');

$mc->content_contains( '<h1>Iniciativas</h1>' );

$mc->get_ok('/iniciativas/' . $id . '/deletar');
$mc->content_contains( 'deleção' );

$mc->submit_form_ok({
    with_fields => {
        'delete-confirmation' => "deletar",
    },
}, 'Fill the form correctly in order to confirm deletion');

$mc->content_contains( 'Iniciativa deletada' );

like( $mc->uri, qr/iniciativas$/ );

done_testing;
