do $$
declare
  login_definition text;
begin
  if to_regprocedure('extensions.gen_salt(text,integer)') is null then
    raise exception 'extensions.gen_salt(text,integer) no existe';
  end if;
  if to_regprocedure('extensions.crypt(text,text)') is null then
    raise exception 'extensions.crypt(text,text) no existe';
  end if;
  if to_regprocedure('public.login_usuario(text,text)') is null then
    raise exception 'public.login_usuario(text,text) no existe';
  end if;

  select pg_get_functiondef('public.login_usuario(text,text)'::regprocedure)
  into login_definition;
  if position('extensions.crypt(' in login_definition) = 0 then
    raise exception 'login_usuario no usa extensions.crypt';
  end if;
end;
$$;

select
  to_regprocedure('extensions.gen_salt(text,integer)') as gen_salt,
  to_regprocedure('extensions.crypt(text,text)') as crypt;
