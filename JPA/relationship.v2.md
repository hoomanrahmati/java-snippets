## Relationship v2

[back](README.md)

### OneToMany

### 1.

- Student(0..) -> (1)Guide
- owner: Student ... @JoinColumn(name = "guide_id") ... **guide_id** is the forign key column in table **student**.
- inverse end!: Guide

```java
@Entity
@Table(name = "guide")
public class Guide {
    @Id
    @GeneratedValue(strategy = GenerationType.SEQUENCE)
    private Long id;
    private String name;
}
```

```java
@Entity
@Table(name = "student")
public class Student {
    @Id
    @GeneratedValue(strategy = GenerationType.SEQUENCE)
    private Long id;
    private String name;

    @ManyToOne
    @JoinColumn(name = "guide_id")
    private Guide guide;
}
```

- main

```java
Student student = new Student();
Guide guide = new Guide();

guide.setName("Jane");

student.setName("Jack");
student.setGuide(guide);

em.persist(student);
em.persist(guide);
```

- sql result:

```sql
create table guide (id bigint not null, name varchar(255), primary key (id))
create table student (id bigint not null, name varchar(255), guide_id bigint, primary key (id))
create sequence student_SEQ start with 1 increment by 50
alter table if exists student add constraint FKfwnod6lgow0caf1eu0n5sv9qo foreign key (guide_id) references guide
select nextval('student_SEQ')
select nextval('guide_SEQ')
insert into student (guide_id,name,id) values (?,?,?)
insert into guide (name,id) values (?,?)
update student set guide_id=?,name=? where id=?
```

### 2. cascade

- add cascade into owner of relationship:

```java
public class Student {
    ...
    @ManyToOne(cascade = {CascadeType.PERSIST})
    @JoinColumn(name = "guide_id")
    private Guide guide;
    ...
}
```

- then we can remove extra em.persist for inverse end relationship:

```java
Student s1 = new Student();
Guide guide = new Guide();

guide.setName("Jane");

s1.setName("John");
s1.setGuide(guide);

em.persist(s1);
// em.persist(guide);
```

- sql result:

```sql
...
select nextval('student_SEQ')
select nextval('guide_SEQ')
insert into guide (name,id) values (?,?)
insert into student (guide_id,name,id) values (?,?,?)
```

- add existing inverse end into new relationship

```java
Student s1 = new Student();
Guide guide = em.find(Guide.class, 252L);

s1.setName("Jack");
s1.setGuide(guide);

em.persist(s1);
```

```sql
select g1_0.id,g1_0.name from guide g1_0 where g1_0.id=?
select nextval('student_SEQ')
insert into student (guide_id,name,id) values (?,?,?)
```

- fetch Owner side with multiple inverse end:

```java
List<Student> students= em.createQuery("select s from Student s")
                .getResultList();
```

```sql
(owner=>) select s1_0.id,s1_0.guide_id,s1_0.name from student s1_0
(inverse end=>) select g1_0.id,g1_0.name from guide g1_0 where g1_0.id=?
(inverse end=>) select g1_0.id,g1_0.name from guide g1_0 where g1_0.id=?
```

- so we have N+1 problem, so use join fetch:

```java
List<Student> students= em.createQuery("select s from Student s left join fetch s.guide", Student.class)
                          .getResultList();
```

```sql
select s1_0.id,g1_0.id,g1_0.name,s1_0.name
from student s1_0
left join guide g1_0 on g1_0.id=s1_0.guide_id
```

- use **fetch** in joining table, otherwise it is like:

```sql
select s1_0.id,s1_0.guide_id,s1_0.name from student s1_0
select g1_0.id,g1_0.name from guide g1_0 where g1_0.id=?
select g1_0.id,g1_0.name from guide g1_0 where g1_0.id=?
```

### 3. cascade should be in owner side, because the inverse end don't care about the forign key column.

```java
public class Student { // owner
    ...
    @ManyToOne
    @JoinColumn(name = "guide_id")
    private Guide guide;
    ...
}
```

```java
public class Guide { // inverse end
    ...
    @OneToMany(mappedBy = "guide", cascade = CascadeType.ALL)
    private Set<Student> students = new HashSet<Student>();
    ...
}
```

```java
Guide g1 = new Guide();
g1.getStudents().add(s1); // don't set guide_id in student table
em.persist(g1);
```

- it just add student and a guide (student without guide_id). So whe need extra methode:

```java
public class Guide {
    @OneToMany(mappedBy = "guide", cascade = CascadeType.ALL)
    private Set<Student> students = new HashSet<Student>();
    ...
    public void addStudent(Student student) {
        // handle add guide to student manually
        students.add(student);
        student.setGuide(this);
    }
}
```

- then istead of using g1.getStudents().add(s1) we should use g1.addStudent(s1)

```java
Student s1 = new Student();
Student s2 = new Student();
Student s3 = new Student();
Guide g1 = new Guide();
Guide g2 = new Guide();

g1.setName("First Guide");
g2.setName("Second Guide");

s1.setName("first");
s2.setName("second");
s3.setName("third");

g1.addStudent(s1);
g1.addStudent(s2);
g2.addStudent(s3);

em.persist(g1);
em.persist(g2);
```

### Orphan Removal

we need to have cascade for remove then it will remove the parent. if parent has another reference with other rows then it throw error so we need to add orphanRemoval in inverse end to true, to remove all the related rows.

- in owner: @ManyToOne(cascade = CascadeType.REMOVE)
- in inverse end, @OneToMany(mappedBy = "guide", orphanRemoval = true)

```java
@Entity
@Table(name = "guide")
public class Guide {
  ...
    @OneToMany(mappedBy = "guide", orphanRemoval = true)
    private Set<Student> students;
  ...
}
```

```java
Student s1 = em.find(Student.class, 402L);
em.remove(s1);
```

```sql
(get the owner):
  select s1_0.id,g1_0.id,g1_0.name,s1_0.name from student s1_0 left join guide g1_0 on g1_0.id=s1_0.guide_id where s1_0.id=?
(get all the relation with inverse end):
  select s1_0.guide_id,s1_0.id,s1_0.name from student s1_0 where s1_0.guide_id=?
(remove the owner):
  delete from student where id=?
(remove the related):
  delete from student where id=?
(remove the inverse end):
  delete from guide where id=?
```

### OneToMany (without ManyToOne)

- this one create join table with name band_artist(band_id(PK), artists_id(PK))...

```java
public class Band {
    @Id
    @GeneratedValue(strategy = GenerationType.SEQUENCE)
    private Long id;

    private String name;

    @OneToMany(cascade = CascadeType.PERSIST)
    private Set<Artist> artists= new HashSet<>();
    // getters and setters
}
```

```java
public class Artist {
    @Id
    @GeneratedValue(strategy = GenerationType.SEQUENCE)
    private Long id;

    private String name;
    // getters and setters
}
```

```java
Band b1 = new Band();
Band b2 = new Band();
b1.setName("B1");
b2.setName("B2");

Artist a1 = new Artist();
a1.setName("A1");
Artist a2 = new Artist();
a2.setName("A2");
Artist a3 = new Artist();
a3.setName("A3");
Artist a4 = new Artist();
a4.setName("A4");
Artist a5 = new Artist();
a5.setName("A5");

b1.getArtists().add(a1);
b1.getArtists().add(a2);
b1.getArtists().add(a3);

b2.getArtists().add(a4);
b2.getArtists().add(a5);

em.persist(b1);
em.persist(b2);
```

```sql
insert into band (name,id) values (?,?)
insert into artist (name,id) values (?,?)
insert into artist (name,id) values (?,?)
insert into artist (name,id) values (?,?)
insert into band (name,id) values (?,?)
insert into artist (name,id) values (?,?)
insert into artist (name,id) values (?,?)
insert into band_artist (Band_id,artists_id) values (?,?)
insert into band_artist (Band_id,artists_id) values (?,?)
insert into band_artist (Band_id,artists_id) values (?,?)
insert into band_artist (Band_id,artists_id) values (?,?)
insert into band_artist (Band_id,artists_id) values (?,?)
```

### Embeddable class

```java
@Embeddable
public class Address {
  private String city;
  private String street;
  private String code;
  ...
}
```

```java
public class Person {
    ...
    @Embedded
    @AttributeOverrides({
            @AttributeOverride(name = "city", column = @Column(name = "address_city")),
            @AttributeOverride(name="street", column = @Column(name="address_street")),
            @AttributeOverride(name="code", column = @Column(name = "address_code"))
    })
    private Address address=new Address();
    ...
}
```

### ManyToMany

```java
public class Movie {
    ...
    @ManyToMany(cascade = CascadeType.ALL)
    @JoinTable(name = "movie_actor",
            joinColumns = @JoinColumn(name = "movie_id"),
            inverseJoinColumns = @JoinColumn(name = "actor_id"))
    private Set<Actor> actors= new HashSet<Actor>();
    ...
}
```

```java
public class Actor {
    ...
    @ManyToMany(mappedBy = "actors")
    private Set<Movie> movies=new HashSet<Movie>();
    ...

    public void addMovie(Movie movie){
        movies.add(movie);
        movie.getActors().add(this);
    }
}
```

```java
Movie m1 = new Movie();
m1.setTitle("first movie");
Movie m2 = new Movie();
m2.setTitle("second movie");
Movie m3 = new Movie();
m3.setTitle("third movie");

Actor a1 = new Actor();
a1.setName("first actor");
Actor a2 = new Actor();
a2.setName("second actor");
Actor a3 = new Actor();
a3.setName("third actor");
Actor a4 = new Actor();
a4.setName("fourth actor");
Actor a5 = new Actor();
a5.setName("fifth actor");

m1.getActors().add(a1);
m1.getActors().add(a2);
m1.getActors().add(a3);
m2.getActors().add(a4);
m3.getActors().add(a5);

// a1.addMovie(m1);
// a2.addMovie(m1);
// a3.addMovie(m1);
// a4.addMovie(m2);
// a5.addMovie(m2);

em.persist(m1);
em.persist(m2);
em.persist(m3);

```

```sql
insert into movie (title,id) values (?,?)
insert into actor (name,id) values (?,?)
insert into actor (name,id) values (?,?)
insert into actor (name,id) values (?,?)

insert into movie (title,id) values (?,?)
insert into actor (name,id) values (?,?)

insert into movie (title,id) values (?,?)
insert into actor (name,id) values (?,?)

insert into movie_actor (movie_id,actor_id) values (?,?)
insert into movie_actor (movie_id,actor_id) values (?,?)
insert into movie_actor (movie_id,actor_id) values (?,?)
insert into movie_actor (movie_id,actor_id) values (?,?)
insert into movie_actor (movie_id,actor_id) values (?,?)
```

### OneToOne

```java
public class Film {
  ...
  @OneToOne(cascade = CascadeType.ALL )
  @JoinColumn(name = "film_content_id", unique = true)
  private FilmContent content;
  ...
}
```

```java
public class FilmContent {
  ...
  @OneToOne(mappedBy = "content")
  private Film film;
  ...
}
```

```java
Film f1 = new Film();
f1.setTitle("first film");
Film f2 = new Film();
f2.setTitle("second film");

FilmContent fc1 = new FilmContent();
fc1.setDescription("first film description");
FilmContent fc2 = new FilmContent();
fc2.setDescription("second film description");

f1.setContent(fc1);
f2.setContent(fc2);

em.persist(f1);
em.persist(f2);
```

```sql
insert into film_content (description,id) values (?,?)
insert into film (film_content_id,title,id) values (?,?,?)
insert into film_content (description,id) values (?,?)
insert into film (film_content_id,title,id) values (?,?,?)
```

### enum

```java
@Entity
@Table(name = "employee")
public class Employee {
    @Id
    @GeneratedValue(strategy = GenerationType.AUTO)
    private int id;
    private String name;

    @Enumerated(EnumType.STRING)
    private EmployeeStatus status;
    ...
}
```

```java
public enum EmployeeStatus {
    FULL_TIME,
    PART_TIME,
    CONTRACT_TIME,
}
```

```java
  Employee e1 = new Employee("first emp", EmployeeStatus.FULL_TIME);
  Employee e2 = new Employee("second emp", EmployeeStatus.PART_TIME);
  Employee e3 = new Employee("third emp", EmployeeStatus.CONTRACT_TIME);

  em.persist(e1);
  em.persist(e2);
  em.persist(e3);
```

```java
  List<Employee> employees= em.createQuery("""
      select e from Employee e
  """, Employee.class).getResultList();
  employees.forEach(System.out::println);
```

### Map Collection of Value or @Embeddable class

- Collection of simple type

```java
@Entity
@Table(name = "person_name")
public class PersonName {
    @Id
    @GeneratedValue(strategy = GenerationType.AUTO)
    private Long id;
    private String fullName;

    @ElementCollection
    @CollectionTable(name = "person_name_nickname", joinColumns = @JoinColumn(name = "person_name_id"))
    @Column(name="nickname")
    private Set<String> nickNames=new HashSet<String>();
    ...
}
```

```java
    PersonName p1 = new PersonName();
    p1.setFullName("first name and last name");
    p1.setEmail("first@email.com");

    p1.getNickNames().add("first");
    p1.getNickNames().add("second");
    p1.getNickNames().add("third");

    em.persist(p1);
```

person_name{id, fullname} (1)<-(\*) person_name_nickname{person_name_id, nickname}

- Collection of embeddable class

```java
@Embeddable
public class Task {
    private String title;
    private Integer duration;
    @Enumerated(EnumType.STRING)
    private TaskStatus status;
    ...
}
```

```java
public enum TaskStatus {
    not_started,
    in_progress,
    completed,
}
```

```java
@Entity
@Table(name="project")
public class Project {
    @Id
    @GeneratedValue(strategy = GenerationType.AUTO)
    private Long id;

    private String name;

    @ElementCollection
    @CollectionTable(name = "project_task", joinColumns = @JoinColumn(name = "project_id"))
    private Set<Task> tasks= new HashSet<Task>();
    ...
}
```

```java
    Project p1 = new Project();
    p1.setName("P2");
    Task t1= new Task("t1-2", 5, TaskStatus.not_started);
    Task t2= new Task("t2-2", 5, TaskStatus.in_progress);
    Task t3= new Task("t3-2", 10, TaskStatus.completed);

    p1.getTasks().add(t1);
    p1.getTasks().add(t2);
    p1.getTasks().add(t3);

    em.persist(p1);
```

project{id, name} (1)<-(\*) task{project_id, title, duration, status}

### Composite Primary key

```java
@Embeddable
public class ParentPrimaryKey implements Serializable {
    private String firstName;
    private String lastName;

    ...

    @Override
    public boolean equals(Object object) {
        if (this == object) return true;
        if (object == null || getClass() != object.getClass()) return false;
        ParentPrimaryKey that = (ParentPrimaryKey) object;
        return Objects.equals(firstName, that.firstName) && Objects.equals(lastName, that.lastName);
    }

    @Override
    public int hashCode() {
        return Objects.hash(firstName, lastName);
    }
}
```

```java
@Entity
@Table(name = "parent_tbl")
public class Parent {
    @EmbeddedId
    private ParentPrimaryKey id;

    public Parent(){}
    public Parent(ParentPrimaryKey id) {
        this.id = id;
    }

    public ParentPrimaryKey getId() {
        return id;
    }

    public void setId(ParentPrimaryKey id) {
        this.id = id;
    }

}

```

```java
  ParentPrimaryKey pk = new ParentPrimaryKey("John", "Smith");
  Parent p1 = new Parent();
  p1.setId(pk);
  em.persist(p1);
```

### Composite Primary key(without @Embeddable)

```java
public class A implements Serializable {
    private String firstName;
    private String lastName;

    ...

    @Override
    public boolean equals(Object object) {
        if (this == object) return true;
        if (object == null || getClass() != object.getClass()) return false;
        ParentPrimaryKey that = (ParentPrimaryKey) object;
        return Objects.equals(firstName, that.firstName) && Objects.equals(lastName, that.lastName);
    }

    @Override
    public int hashCode() {
        return Objects.hash(firstName, lastName);
    }
}
```

```java
@IdClass(A.class)
@Entity
public class B {
    @Id
    private String firstName;

    @Id
    private String lastName;

    private String address;
    ...
}

```

```java
  Parent p1 = new Parent("John", "Doe", "Dehli");
  em.persist(p1);
```

```java
  Parent p = em.find(B.class, new A("John", "Doe"));
```

### Composite Primary Key and Composite Foreign Key

```java
@Embeddable
public class ParentPrimaryKey implements Serializable {
    private String firstName;
    private String lastName;

    public ParentPrimaryKey() {}
    public ParentPrimaryKey(String firstName, String lastName) {
        this.firstName = firstName;
        this.lastName = lastName;
    }
    ...

    @Override
    public boolean equals(Object object) {
        if (this == object) return true;
        if (object == null || getClass() != object.getClass()) return false;
        ParentPrimaryKey that = (ParentPrimaryKey) object;
        return Objects.equals(firstName, that.firstName) && Objects.equals(lastName, that.lastName);
    }

    @Override
    public int hashCode() {
        return Objects.hash(firstName, lastName);
    }
}
```

```java
@Entity
@Table(name = "parent_tbl")
public class Parent {
    @EmbeddedId
    private ParentPrimaryKey id;

    @OneToMany(mappedBy = "parent", cascade = CascadeType.ALL, orphanRemoval = true)
    private Set<Child> children= new HashSet<Child>();

    ...

    public void addChild(Child child){
        children.add(child);
        child.setParent(this);
    }

}
```

```java
@Entity
@Table(name = "child_tbl")
public class Child {
    @Id
    @GeneratedValue(strategy = GenerationType.AUTO)
    private int id;
    private String name;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumns(value = {@JoinColumn(name = "firstNamePk", referencedColumnName = "firstname"),
            @JoinColumn(name = "lastNamePk", referencedColumnName = "lastname")}, foreignKey =@ForeignKey(name = "FKChild_parent_Parent"))
    private Parent parent;
    ...
}
```

```java
  ParentPrimaryKey pk = new ParentPrimaryKey("Jane", "Smith");
  Parent p1 = new Parent(pk);

  Child child1 = new Child();
  Child child2 = new Child();
  Child child3 = new Child();

  child1.setName("Mamad");
  child2.setName("Majid");
  child3.setName("Mahmood");

  p1.addChild(child1);
  p1.addChild(child2);
  p1.addChild(child3);

  em.persist(p1);
```

```sql
  insert into parent_tbl (firstName,lastName) values (?,?)
  insert into child_tbl (name,firstNamePk,lastNamePk,id) values (?,?,?,?)
  insert into child_tbl (name,firstNamePk,lastNamePk,id) values (?,?,?,?)
  insert into child_tbl (name,firstNamePk,lastNamePk,id) values (?,?,?,?)
```

### Foreign Key in Composite Primary Key (using MapsId => Drived Identifier Mapping)

```java
@Entity
@Table(name = "department_tbl")
public class Department {
    @Id
    @GeneratedValue(strategy = GenerationType.AUTO)
    private Long id;
    private String name;
    ...
}
```

```java
@Embeddable
public class UserId implements Serializable {
    private String username;
    private Long departmentId;

    public UserId() {}
    public UserId(String username, Long departmentId) {
        this.username = username;
        this.departmentId = departmentId;
    }
    ...
    @Override
    public boolean equals(Object object) {
        if (this == object) return true;
        if (object == null || getClass() != object.getClass()) return false;
        UserId userId = (UserId) object;
        return Objects.equals(username, userId.username) && Objects.equals(departmentId, userId.departmentId);
    }

    @Override
    public int hashCode() {
        return Objects.hash(username, departmentId);
    }
}
```

```java
@Entity
@Table(name="user_info")
public class User {
    @EmbeddedId
    private UserId id;

    private String email;

    @ManyToOne
    @JoinColumn(name = "department_fk_id")
    @MapsId("departmentId") // this line ignoe the departmentId from the UserId class
    private Department department;
    ...
}
```

```java
  Department d1 = new Department();
  d1.setName("Agriculture");
  em.persist(d1);

  // we can pass null instead of d1.getId()
  User user= new User(new UserId("Majid", d1.getId()), "email@email.com");
  // this line is mandatory
  user.setDepartment(d1);
  em.persist(user);
```

```sql
 insert into department_tbl (name,id) values (?,?)
 insert into user_info (email,department_fk_id,username) values (?,?,?)
```

### Mapping Json

```xml
<dependency>
    <groupId>com.fasterxml.jackson.core</groupId>
    <artifactId>jackson-core</artifactId>
    <version>2.15.2</version>
</dependency>

<!-- Jackson Databind -->
<dependency>
    <groupId>com.fasterxml.jackson.core</groupId>
    <artifactId>jackson-databind</artifactId>
    <version>2.15.2</version>
</dependency>

<!-- Jackson annotations (optional but recommended) -->
<dependency>
    <groupId>com.fasterxml.jackson.core</groupId>
    <artifactId>jackson-annotations</artifactId>
    <version>2.15.2</version>
</dependency>

<!-- Hibernate specific Jackson integration -->
<dependency>
    <groupId>com.fasterxml.jackson.datatype</groupId>
    <artifactId>jackson-datatype-jsr310</artifactId>
    <version>2.15.2</version>
</dependency>
```

```java
public class Specification {
    private Integer ram;
    private Integer internalMemory;
    private String processor;

    public Specification(Integer ram, Integer internalMemory, String processor) {
        this.ram = ram;
        this.internalMemory = internalMemory;
        this.processor = processor;
    }
    // getters and setters are important!
}
```

```java
@Entity
@Table(name="phone_tbl")
public class Phone {
    @Id
    @GeneratedValue(strategy = GenerationType.AUTO)
    private Long id;

    private String name;

    @JdbcTypeCode(SqlTypes.JSON)
    private Specification specification;
    ...
}
```

```java
    Phone p1 = new Phone("Zebra", new Specification(8, 8 , "Dragen"));
    em.persist(p1);
```

```java
    Phone p1 = em.find(Phone.class, 2L);
    Specification s= p1.getSpecification();
    System.out.println(p1);
    System.out.println(s);
```
