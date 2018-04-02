package Roseno::Controller::Initiatives;
use Moose;
use namespace::autoclean;
use utf8;
use HTML::FormFu;

BEGIN { extends 'Catalyst::Controller' }

sub base :Chained('/') PathPart('iniciativas') CaptureArgs(0) {
    my ( $self, $c ) = @_;
    my @protected_actions = qw/add edit delete/;

    if ( ( grep { $c->action->name eq $_ } @protected_actions )
         &&
         ! $c->check_any_user_role('admin')
       ) {
        $c->res->redirect($c->uri_for_action('/login'));
        $c->detach;
    }

    $c->stash(initiatives_rs => $c->model('DB::Initiative'),
              page_title => 'Iniciativas');
}

sub object :Chained('base') PathPart('') CaptureArgs(1) {
    my ( $self, $c, $initiative_id ) = @_;
    my $initiative = $c->stash->{initiatives_rs}->find( $initiative_id );

    $c->stash(initiative => $initiative);
}

sub index :Chained('base') PathPart('') Args(0) {
    my ( $self, $c ) = @_;
    my $page = $c->req->params->{pagina} || 1;
    my $initiatives_rs = $c->stash->{initiatives_rs}->search
      (undef,
       { order_by => { -desc => 'published' },
         page => $page });

    $c->stash(initiatives => [$initiatives_rs->all],
              pager => $initiatives_rs->pager);
}

sub details :Chained('object') PathPart('') Args(0) {
    my ($self, $c) = @_;
    my $initiative = $c->stash->{initiative};

    $c->stash(page_title => $initiative->title,
              og => { title => $initiative->title,
                      type => 'article',
                      url => $c->req->uri,
                      description => $initiative->subtitle });
}

sub add :Chained('base') PathPart('adicionar') Args(0) {
    my ( $self, $c ) = @_;

    if ( $c->req->params->{'submit_cancel'} ) {
        $c->flash->{success_msg} = 'Adição cancelada.';
        $c->res->redirect($c->uri_for_action('/initiatives/index'));
        $c->detach;
    }

    my $form = HTML::FormFu->new( _formfu_initiative_config() );
    $form->stash->{schema} = $c->model('DB')->schema;
    $form->process( $c->req->params );

    if ($form->submitted_and_valid) {
        if (my $upload = $c->req->uploads->{image}) {
            my $filename = $c->model('Files')->add_file
              ($upload->tempname, $upload->filename, 'resize');
            $form->add_valid('image', $filename);
        }

        my $initiative = $form->model->create;
        _process_uploads($c, $initiative, 'add_to_initiative_files', 'id');
        $c->flash->{success_msg} = 'Iniciativa adicionada.';

        if ($c->req->params->{'submit_details'}) {
            $c->res->redirect($c->uri_for_action('/initiatives/details',
                                                 [$initiative->id]));
        }
        else {
            $c->res->redirect($c->uri_for_action('/initiatives/edit',
                                                 [$initiative->id]));
        }

        $c->detach;
    }

    $c->stash(form => $form);
}

sub edit :Chained('object') PathPart('editar') Args(0) {
    my ( $self, $c ) = @_;
    my $initiative = $c->stash->{initiative};

    if ( $c->req->params->{'submit_cancel'} ) {
        $c->flash->{success_msg} = 'Edição cancelada.';
        $c->res->redirect($c->uri_for_action('/initiatives/details',
                                             [$initiative->id]));
        $c->detach;
    }

    my $form = HTML::FormFu->new( _formfu_initiative_config() );
    $form->stash->{schema} = $c->model('DB')->schema;
    $form->stash->{self_stash_key} = $initiative;
    $form->process( $c->req->params );

    if ($form->submitted_and_valid) {
        if (my $upload = $c->req->uploads->{image}) {
            $c->model('Files')->delete_file($initiative->image);

            my $filename = $c->model('Files')->add_file
              ($upload->tempname, $upload->filename, 'resize');
            $form->add_valid('image', $filename);
        }

        $form->model->update($initiative);
        _process_uploads($c, $initiative, 'add_to_initiative_files', 'id');
        _process_deletes($c, $initiative, 'initiative_files');
        $c->flash->{success_msg} = 'Iniciativa editada.';

        if ($c->req->params->{'submit_details'}) {
            $c->res->redirect($c->uri_for_action('/initiatives/details',
                                                 [$initiative->id]));
        }
        else {
            $c->res->redirect($c->uri_for_action('/initiatives/edit',
                                                 [$initiative->id]));
        }

        $c->detach;
    }
    else {
        $form->model->default_values( $initiative );
    }

    $c->stash(form => $form);
}

sub delete :Chained('object') PathPart('deletar') Args(0) {
    my ( $self, $c ) = @_;

    if ( $c->req->params->{'submit_cancel'} ) {
        $c->res->redirect($c->uri_for_action('/initiatives/details',
                                             [$c->stash->{initiative}->id]));
        $c->detach;
    }

    my $form = HTML::FormFu->new({
        load_config_file => 'formfu-config.pl',
        elements => [
            { type => 'Text',
              name => 'delete-confirmation',
              label => 'Confirmação de deleção',
              constraints => ['Required',
                              { type => 'Regex',
                                regex => qr/^deletar$/i,
                                message => 'Palavra deve ser "deletar"' } ],
              attrs => { class => 'form-control' } },
            { type => 'Submit',
              value => 'Enviar',
              container_tag => 'span',
              attrs => { class => 'btn btn-primary' } },
            { type => 'Submit',
              name => 'submit_cancel',
              value => 'Cancelar',
              container_tag => 'span',
              attrs => { class => 'btn btn-default' } },
        ],
    });

    $form->process( $c->req->params );

    if ($form->submitted_and_valid) {
        for my $file ($c->stash->{initiative}->initiative_files) {
            $c->model('Files')->delete_file( $file->id );
        }

        $c->stash->{initiative}->delete;
        $c->flash->{success_msg} = 'Iniciativa deletada.';
        $c->res->redirect( $c->uri_for_action('/initiatives/index') );
        $c->detach;
    }

    $c->stash(form => $form);
}

sub _process_uploads {
    my ( $c, $row, $rel, $key ) = @_;

    return if ! $c->req->uploads->{files_to_attach};

    use Scalar::Util qw/reftype/;
    my @uploads = reftype $c->req->uploads->{files_to_attach} eq 'ARRAY' ?
        @{ $c->req->uploads->{files_to_attach} }
      :    $c->req->uploads->{files_to_attach};

    for my $upload (@uploads) {
        my $resize = $upload->filename =~ m{\.(jpg|png|gif)$};
        my $filename = $c->model('Files')->add_file
          ($upload->tempname, $upload->filename, $resize);
        $row->$rel({ $key => $filename });
    }
}

sub _process_deletes {
    my ( $c, $row, $rel ) = @_;
    my @filenames_to_delete;

    if (ref $c->req->params->{files_to_delete}) {
        @filenames_to_delete = @{ $c->req->params->{files_to_delete} }
    }
    elsif ( $c->req->params->{files_to_delete} ) {
        @filenames_to_delete = ( $c->req->params->{files_to_delete} )
    }

    for my $filename_to_delete (@filenames_to_delete) {
        my $file = $row->$rel->find( $filename_to_delete );
        $file->delete;
        $c->model('Files')->delete_file( $filename_to_delete );
    }
}

sub _formfu_initiative_config {
    return {
        load_config_file => 'formfu-config.pl',
        model_config => { resultset => 'Initiative' },
        elements => [
            { type => 'Text',
              name => 'id',
              constraints => [
                  'Required',
                  { type => 'DBIC::Unique',
                    resultset => 'Initiative',
                    self_stash_key => 'self_stash_key',
                    message => 'Este identificador já está sendo usado' },
                  { type => 'Regex',
                    regex => '^[a-z0-9-]+$' }
              ],
              label => 'Identificador para o endereço web',
              comment => 'Use só minúsculas de "a" a "z", hífens e números; sem espaços',
              attrs => { class => 'form-control' }
            },

            { type => 'Text',
              name => 'title',
              label => 'Título',
              constraints => 'Required',
              attrs => { class => 'form-control' } },

            { type => 'Textarea',
              name => 'subtitle',
              label => 'Subtítulo',
              constraints => 'Required',
              attrs => { class => 'form-control', rows => 3 } },

            { type => 'Textarea',
              name => 'body',
              label => 'Corpo',
              constraints => 'Required',
              attrs => { class => 'form-control', rows => '15' } },

            { type => 'Text',
              name => 'published',
              label => 'Data',
              constraints => [ 'Required',
                               { type => 'DateTime',
                                 parser => { strptime => '%d/%m/%Y %H:%M' } } ],
              inflator => { type => 'DateTime',
                            parser => { strptime => '%d/%m/%Y %H:%M' } },
              deflator => { type => 'Strftime',
                            strftime => '%d/%m/%Y %H:%M' },
              attrs => { class => 'form-control datetimepicker' } },

            { type => 'File',
              name => 'image',
              label => 'Imagem principal',
              model_config => { ignore_if_empty => 1 }, },

            { type => 'Textarea',
              name => 'image_subtitle',
              label => 'Imagem principal: legenda',
              attrs => { class => 'form-control', rows => 3 } },

            { type => 'Textarea',
              name => 'image_alt_text',
              label => 'Imagem principal: texto alternativo',
              attrs => { class => 'form-control', rows => 3 } },

            { type => 'File',
              name => 'files_to_attach',
              label => 'Arquivos para anexar',
              model_config => { ignore_if_empty => 1 },
              attrs => { multiple => 'multiple' } },

            { type => 'Submit',
              name => 'submit_details',
              value => 'Salvar e visualizar',
              container_tag => 'span',
              attrs => { class => 'btn btn-primary' } },

            { type => 'Submit',
              name => 'submit_edit',
              value => 'Salvar e continuar editando',
              container_tag => 'span',
              attrs => { class => 'btn btn-primary' } },

            { type => 'Submit',
              name => 'submit_cancel',
              value => 'Cancelar',
              container_tag => 'span',
              attrs => { class => 'btn btn-default' } },
        ],
    };
}

__PACKAGE__->meta->make_immutable;

1;
