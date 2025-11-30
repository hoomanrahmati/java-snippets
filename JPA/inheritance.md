## Inheritance

[back](README.md)

### @MappedSuperclass

```java
@MappedSuperclass
public class Account {
    @Id
    @GeneratedValue(strategy = GenerationType.SEQUENCE)
    private Long id;

    private String owner;
    private BigDecimal balance;
    ...
}
```

```java
@Entity
@Table(name = "debit_account")
public class DebitAccount extends Account {
    @Column(name = "overdraft_fee")
    private BigDecimal overdraftFee;
    ...
}
```

```java
@Entity
@Table(name = "credit_account")
public class CreditAccount extends Account {
    @Column(name = "credit_limit")
    private BigDecimal creditLimit;
    ...
}
```

```sql
create table credit_account (id bigint not null, balance numeric(38,2), owner varchar(255), credit_limit numeric(38,2), primary key (id))
create table debit_account (id bigint not null, balance numeric(38,2), owner varchar(255), overdraft_fee numeric(38,2), primary key (id))
create sequence credit_account_SEQ start with 1 increment by 50
create sequence debit_account_SEQ start with 1 increment by 50
```

### SINGLE_TABLE, JOINED, TABLE_PER_CLASS

- SINGLE_TABLE
- JOINED
- TABLE_PER_CLASS

```java
@Entity
@Inheritance(strategy = InheritanceType.SINGLE_TABLE)
public abstract class Animal {
    @Id
    @GeneratedValue(strategy = GenerationType.SEQUENCE)
    private Long id;

    private String name;

    abstract protected String makeSound();
    ...

    @Override
    public String toString() {
        return "Animal [id=" + id + ", name=" + name + ", makeSound=" + makeSound() + "]";
    }
}
```

```java
@Entity
public class Cat extends Animal {
    @Column(name = "purring_level")
    private Integer purringLevel;

    public Cat() {}
    ...

    @Override
    protected String makeSound() {
        return "meow meow";
    }
}
```

```java
@Entity
public class Dog extends Animal {
    @Column(name = "barking_level")
    private Integer barkingLevel;

    public Dog() {}
    ...

    @Override
    protected String makeSound() {
        return "woof woof";
    }
}
```

```sql
create table Animal (
  DTYPE varchar(31) not null,
  id bigint not null, name varchar(255),
  barking_level integer,
  purring_level integer,
  primary key (id)
)

create sequence Animal_SEQ start with 1 increment by 50
```

```java
  Cat c= new Cat();
  c.setName("miyam");
  c.setPurringLevel(1);

  Dog d= new Dog();
  d.setName("Peter");
  d.setBarkingLevel(2);

  em.persist(c);
  em.persist(d);
```

```java
  List<Animal> animals=em.createQuery("select a from Animal a", Animal.class).getResultList();
  animals.forEach(System.out::println);

  //Animal [id=1, name=miyam, makeSound=meow meow]
  //Animal [id=2, name=Peter, makeSound=woof woof]
```

## Embeddable Inheritance (in Hibernate 6.6)

```java
@Embeddable
public class Animal2 {
    private String name;
    private Integer age;
    ...
}
```

```java
@Embeddable
public class Dog2 extends Animal2{
    private String breed;
    ...
}
```

```java
@Embeddable
public class Cat2 extends Animal2{
    private String color;
    ...
}
```

```java
@Entity
@Table(name = "owner2")
public class Owner2 {
    @Id
    @GeneratedValue(strategy = GenerationType.SEQUENCE)
    private Long id;

    @Embedded
    private Animal2 animal;
    ...
}
```

```java
create table owner2 (
    id bigint not null,
    animal_DTYPE varchar(31) not null,
    age integer,
    name varchar(255),
    color varchar(255),
    breed varchar(255),
    primary key (id)
)
```

```java
    Owner2 o1=new Owner2();
    Owner2 o2=new Owner2();

    Cat2 c=new Cat2();
    c.setName("My new Cat");
    c.setAge(1);
    c.setColor("Yellow");

    Dog2 d=new Dog2();
    d.setName("Peter");
    d.setAge(2);
    d.setBreed("Street Dog");

    o1.setAnimal(c);
    o2.setAnimal(d);

    em.persist(o1);
    em.persist(o2);
```

```sql
select nextval('owner2_SEQ')
insert into owner2 (age,breed,color,name,animal_DTYPE,id) values (?,?,?,?,?,?)
insert into owner2 (age,breed,color,name,animal_DTYPE,id) values (?,?,?,?,?,?)
```

```java
    Owner2 o= em.find(Owner2.class, 52L);
    Cat2 c= (Cat2) o.getAnimal();
    System.out.println(c);
```

```sql
select o1_0.id,
    o1_0.animal_DTYPE,
    o1_0.age,
    o1_0.breed, //Dog2
    o1_0.color, //Cat2
    o1_0.name
from owner2 o1_0
where o1_0.id=?
```

### @ConcreteProxy (in Hibernate 6.6)

```java
@Entity
@Inheritance(strategy = InheritanceType.SINGLE_TABLE)
@Table(name="animal_3_tbl")
@ConcreteProxy
public class Animal3 {
    @Id
    @GeneratedValue(strategy = GenerationType.SEQUENCE)
    private Long id;

    private String name;
    private Integer age;
    ...
}
```

```java
@Entity
public class Cat3 extends Animal3{
    private String color;
    ...
}
```

```java
@Entity
public class Dog3 extends Animal3 {
    private String breed;
    ...
}
```

```java
@Entity
@Table(name = "owner3")
public class Owner3 {
    @Id
    @GeneratedValue(strategy = GenerationType.SEQUENCE)
    private Long id;

    private String name;

    @ManyToOne(fetch = FetchType.LAZY,cascade = CascadeType.ALL)
    @JoinColumn(name = "animal_id", referencedColumnName = "id")
    private Animal3 animal;
    ...
}
```

```java
    // it get the  owner + Animal Type so the
    Owner3 o=  em.find(Owner3.class, 1L);
    Animal3 a = o.getAnimal();
    // So we know the animal type
    Boolean isCat= a instanceof Cat3;
    System.out.println(isCat); // true
    // it run a query to get all the related data
    // without help of @ConcreteProxy in Animal3 class then it fails
    String  color= ((Cat3) a).getColor();
    System.out.println(color); // Yellow
```

```sql
select o1_0.id,o1_0.animal_id,a1_0.DTYPE,o1_0.name
from owner3 o1_0
left join animal_3_tbl a1_0 on a1_0.id=o1_0.animal_id
where o1_0.id=?

-> true

select c1_0.id,c1_0.age,c1_0.name,c1_0.color
from animal_3_tbl c1_0
where c1_0.DTYPE='Cat3' and c1_0.id=?

-> Yellow
```

### Lifecycle Callbacks, Callback Anotations, Callback Method

Callback Anotations

- @Transient
- @EntityListeners

```java
@Entity
@EntityListeners({PersonListener.class, ...})
public class Person {...}
```

```java
public class PersonListener {
    @PostLoad
    public void sayHello(Object entity) {
        System.out.println("Hello World! "+entity);
    }

    @PostUpdate
    public void sayBye(Object entity) {
        if(entity instanceof Person2) {
            Person2 person = (Person2) entity;
            System.out.println("Bye " + person.getFullName());
        }
    }
}
```

7 Lifecycle Callback Anotations

- @PostLoad
- @PrePersist
- @PostPersist
- @PreUpdate
- @PostUpdate
- @PreRemove
- @PostRemove

```java
@Entity
@Table(name = "person_tbl")
public class Person {
    @Id
    @GeneratedValue(strategy = GenerationType.SEQUENCE)
    private Long id;
    private String name;
    private String lastName;
    @Transient
    private String fullName;

    @Column(name = "last_update")
    private LocalDateTime lastUpdate;
    ...

    @PostLoad
    protected void setFullName() {
        this.fullName = this.name + " " + this.lastName;
    }

    @PrePersist
    @PreUpdate
    public void updateLastUpdate() {
        this.lastUpdate = LocalDateTime.now();
        System.out.printf("Last update: %s\n", this.lastUpdate);
    }
}
```
