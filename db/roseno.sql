create table if not exists users (
    id varchar primary key,
    name varchar,
    password varchar,
    email varchar
);

create table if not exists roles (
    id varchar primary key,
    name varchar
);

create table if not exists users_roles (
    user_id varchar references users on update cascade on delete cascade,
    role_id varchar references roles on update cascade on delete cascade,
    primary key (user_id, role_id)
);

create table if not exists initiatives (
    id varchar primary key,
    title varchar,
    subtitle text,
    body text,
    published timestamptz,
    image varchar,
    image_subtitle text,
    image_alt_text text,
    created timestamptz,
    updated timestamptz
);

create table if not exists initiative_files (
    id varchar primary key,
    initiative_id varchar references initiatives
        on update cascade on delete cascade,
    created timestamptz
);
