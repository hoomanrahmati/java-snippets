## Postgres

- [back](../README.md)

### DDL

```sql
create type sex as enum('male', 'female');
-----------------------------
create table person (
	id integer,
	gender sex,
	name varchar(30),
	birthdate date
);

insert into person values(1, 'male', 'Jack', date('2000/01/01'));
insert into person values(2, 'female', 'Jane', '2001/01/02');
insert into person values(3, 'male', 'Joe Doe', '2001/01/03');
-----------------------------
select * from person limit 1;
select * from person offset 2 limit 1;
select extract (month from birthdate) "month",
	extract(day from birthdate) "day" from person;
-----------------------------
alter table person add column status integer;
alter table person drop column status;
-----------------------------
alter table person add column email varchar(50);
alter table person alter column email set not null;
alter table person alter column name set not null;
alter table person rename name to fname;
alter table person rename column fname to name;

update person set email= name || '@email.com'
insert into person values(4, 'female', 'Jane Doe', '2001/01/04', 'jane.deo@gmail.com');
insert into person values(5, 'male', 'Jim Doe', '2001/10/04', 'jane.deo@gmail.com');
insert into person values(6, 'male', 'John Doe', '2001/11/04', 'john.deo@gmail.com');
-----------------------------
alter table person add constraint person_pk primary key (id);
alter table person add constraint person_name_uk unique(name);
create index on person(birthdate);
create index hello_email on person(email);
drop index hello_email;
-----------------------------
create view johnPerson as select * from person where name like 'John%';
create view joePerson as select * from person where name ~ '^Joe.*';
-----------------------------
select 1 x union select 2;
select name from person where name like '%Doe';
select name from person where name ~ '^J.* .*e$';
select count(*), extract(month from birthdate) m from person group by m;

```

### Function

```sql
create or replace function addValue(int, int) returns int as
'
select $1 + $2;
'
language sql;

create or replace function addValue2(int , int) returns int as
$body$
select $1 + $2;
$body$
language sql;

select addValue2(4, 8);
-----------------------------
create or replace function getPersonNameById(id integer) returns varchar as
$body$
select p.name from person p where p.id=id;
$body$
language sql;

select getPersonNameById(1);
-----------------------------
create or replace function getFirstRecord() returns Person as
$body$
	select * from person limit 1;
$body$
language sql;

select getFirstRecord() -- as one column so don't use "select getFirstRecord().name"
select (getFirstRecord()).* -- as a Person row
select (getFirstRecord()).name
select id, name from getFirstRecord();
-----------------------------
-- setOf is for multi rows
create or replace function get3Record() returns setOf Person as
$body$
	select * from person limit 3;
$body$
language sql;

select get3Record()-- as one column
select (get3Record()).* -- as a Person row
select (get3Record()).name
select id, name from get3Record();
-----------------------------
create or replace function getName(personId integer) returns varchar as
$body$
begin
	return name
	from person where id= personId;
end
$body$
language plpgsql;

select getName(1);
select * from getName(1);

create or replace function addValue3(x float, y float) returns float as
$body$
declare
z float;
begin
	z:= x+y;
	return z;
end
$body$
language plpgsql;

select addValue3(1, 5);
select * from addValue3(3, 6);
-----------------------------
create or replace function getFullNameById(personId integer) returns varchar as
$body$
declare
p record;
begin
select * into p
from person where id= personId;
return concat('Dr.',p.name);
end
$body$
language plpgsql;

select getFullNameById(1);
-----------------------------
-- no return value but out
create or replace function getNameAndEmail(personId integer, out personName varchar, out personEmail varchar)
as
$body$
begin
select name, email into personName, personEmail
from person where id= personId;
end
$body$
language plpgsql;

select (getNameAndEmail(1)).*;
select * from getNameAndEmail(1);
-----------------------------
-- return query for setof Person
create or replace function getAllPerson()
returns setof person as
$body$
begin
	return query
	select * from person;
end
$body$
language plpgsql;

select (getAllPerson()).name;
select * from getAllPerson();
-----------------------------
-- return table(...)
create or replace function findAll()
returns Table(name varchar, email varchar)
language plpgsql as
$body$
begin
	return query
	select p.name, p.email from person p;
end;
$body$;

select * from findAll();
-----------------------------
create or replace function get20() returns int as
'
declare
x int;
begin
	x:=10;
	return x*2;
end;
' language 'plpgsql';

select get20();
```

### Condition and loop

```sql
	do
	$body$
	declare
	begin

	end
	$body$
	language plpgsql;
-----------------------------
	do language plpgsql
	$body$
	declare
	begin

	end
	$body$
-----------------------------
	if x>y then
		return 100;
	elseif x<y then
		return 200;
	else
		return 300;
	end if;
-----------------------------
	case
		when x<y then return 1;
		when x>y then return 2;
		else return 3;
	end case;
-----------------------------
	sum:=0;
	for i in x..y by 2 loop
		sum := sum + i;
	end loop;
-----------------------------
-- in reverse
	sum:=0;
	for i in reverse x..y by 2 loop
		sum := sum + i;
	end loop;
-----------------------------
declare
 sum int;
 i int;
begin
	sum:=0;
	i:=1;
	loop
		sum := sum + i;
		i:=i+1;
		exit when i>9;
	end loop;
end
```

### Cursor

```sql
do language plpgsql
$body$
declare
rec record;
begin
	for rec in
		select id, name, email from person
	loop
		raise notice '% % %', rec.id, rec.name, rec.email;
	end loop;
end
$body$
-----------------------------
```

### Procedure

```sql
-----------------------------

-----------------------------

-----------------------------

-----------------------------

-----------------------------

-----------------------------

-----------------------------

-----------------------------
```
