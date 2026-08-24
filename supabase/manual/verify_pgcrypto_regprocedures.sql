select
  to_regprocedure('extensions.gen_salt(text,integer)') as gen_salt,
  to_regprocedure('extensions.crypt(text,text)') as crypt;
