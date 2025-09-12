## Entity Relationships

[back](README.md)

### Unidirectional Relationship vs. Bidirectional Relationship

### OneToOne Relationship

- @OneToOne
- @JoinColumn(name = "address_id")

```java
@Entity
@Table(name="person")
public class Person {
  ...

  @OneToOne
  @JoinColumn(name = "address_id")
  private Address address;
}
```

```java
@Entity
@Table(name = "address")
public class Address {
  @Id
  @GeneratedValue(strategy = GenerationType.SEQUENCE)
  @Column(name="address_id")
  private Long id;
  ...
}
```

- Bidirectional OneToOne Relationship: add person to Address but with use of mappedBy of OneToOne anotation:

```java
@Entity
@Table(name = "address")
public class Address {
  ...
  @OneToOne(mappedBy = "address")
  private Person person;
  ...
}
```

### ManyToOne and OneToMany Relationship

- One(master): need to use **@OneToMany** anotation and **@JoinColumn**

```java
@Entity
@Table(name = "cart")
public class Cart {
  @Id
  @GeneratedValue(strategy = GenerationType.AUTO)
  @Column(name = "cart_id")
  private Long id;

  @OneToMany(cascade = CascadeType.ALL)
  @JoinColumn(name = "cart_id")
  private List<CartItem> items;
  // getters and setters
}
```

- Many(Detail): need to use **@ManyToOne** anotation

```java
@Entity
@Table(name = "cart_item")
public class CartItem {
  @Id
  @GeneratedValue(strategy = GenerationType.AUTO)
  @Column(name = "cart_item_id")
  private Long id;

  private String name;
  private Integer quantity;
  private BigDecimal price;

  @ManyToOne
  private Cart cart;
  //getters and setters
}
```

Hibernate: insert into cart (cart_id) values (?)

Hibernate: insert into cart_item (cart_cart_id,name,price,quantity,cart_item_id) values (?,?,?,?,?)

Hibernate: insert into cart_item (cart_cart_id,name,price,quantity,cart_item_id) values (?,?,?,?,?)

Hibernate: update cart_item set cart_id=? where cart_item_id=?

Hibernate: update cart_item set cart_id=? where cart_item_id=?

- Bidirectional OneToMany Relationship [Vlad Mihalcea solution](https://vladmihalcea.com/the-best-way-to-map-a-onetomany-association-with-jpa-and-hibernate/)

@OneToMany(mappedBy = "post", cascade = CascadeType.ALL, orphanRemoval = true)

```java
@Entity
@Table(name = "post")
public class Post {
  @Id
  @GeneratedValue(strategy = GenerationType.SEQUENCE)
  @Column(name = "post_id")
  private Long id;

  private String title;

  @OneToMany(mappedBy = "post", cascade = CascadeType.ALL, orphanRemoval = true)
  private List<PostComment> comments;
  // getters and setters
}
```

```java
@Entity
@Table(name="post_comment")
public class PostComment {
  @Id
  @GeneratedValue(strategy = GenerationType.SEQUENCE)
  @Column(name = "post_comment_id")
  private Long id;

  @ManyToOne(fetch = FetchType.LAZY)
  private Post post;

  private String comment;
  // getters and setters
}
```

```sql
Hibernate: insert into post (title,post_id) values (?,?)
Hibernate: insert into post_comment (comment,post_post_id,post_comment_id) values (?,?,?)
Hibernate: insert into post_comment (comment,post_post_id,post_comment_id) values (?,?,?)
```

### ManyToMany Relationship

- owner side: @JoinTable(name = "user_group", joinColumns = @JoinColumn(name = "group_id"), inverseJoinColumns = @JoinColumn(name="user_id"))

```java
@Entity
@Table(name = "group_table")
public class Group {
  @Id
  @GeneratedValue(strategy = GenerationType.SEQUENCE)
  @Column(name = "group_id")
  private Long id;

  @ManyToMany(cascade = CascadeType.ALL)
  @JoinTable(name = "user_group",
          joinColumns = @JoinColumn(name = "group_id"),
          inverseJoinColumns = @JoinColumn(name="user_id"))
  private List<User> users;
  ...
}
```

- @ManyToMany(mappedBy = "users")

```java
@Entity
@Table(name = "user_info")
public class User {
  @Id
  @GeneratedValue(strategy = GenerationType.SEQUENCE)
  @Column(name="user_id")
  private Long id;

  @ManyToMany(mappedBy = "users")
  private List<Group> groups;
  ...
}
```

- main function:

```java
User user1 = new User();
User user2 = new User();

Group group1= new Group();
Group group2=new Group();

user1.setUsername("first user");
user2.setUsername("second user");

group1.setName("First Group");
group2.setName("Second Group");

group1.setUsers(List.of(user1, user2));
group2.setUsers(List.of(user2));

em.persist(group1);
em.persist(group2);
```

```sql
Hibernate: insert into group_table (group_name,group_id) values (?,?)
Hibernate: insert into user_info (user_name,user_id) values (?,?)
Hibernate: insert into user_info (user_name,user_id) values (?,?)
Hibernate: insert into group_table (group_name,group_id) values (?,?)
Hibernate: insert into user_group (group_id,user_id) values (?,?)
Hibernate: insert into user_group (group_id,user_id) values (?,?)
Hibernate: insert into user_group (group_id,user_id) values (?,?)
```

## Jpa and Inheritance

1. Mapped Superclass
2. Single Table
3. Joined Table
4. Table per class

### Mapped Superclass

- @MappedSuperclass
- Parent class is abstract
- Then we have 2 tables in database named cat and fish

```java
@MappedSuperclass
public abstract class Animal {
  @Id
  @GeneratedValue(strategy = GenerationType.SEQUENCE)
  @Column(name = "animal_id")
  private Long id;

  private String name;
  ...
}
```

```java
@Entity
@Table(name="cat")
public class Cat extends Animal {
  private String breed;
  ...
}
```

```java
@Entity
@Table(name = "fish")
public class Fish extends Animal {
  private String color;
  ...
}
```

```sql
Hibernate: insert into fish (color,name,animal_id) values (?,?,?)
Hibernate: insert into cat (breed,name,animal_id) values (?,?,?)
```

### Single table strategy for 2 class with DiscriminatorColumn

- @Inheritance(strategy = InheritanceType.SINGLE_TABLE)

- @DiscriminatorColumn(name = "animal_type")

- @DiscriminatorValue("cat")

```java
@Entity
@Table(name = "animal2")
@Inheritance(strategy = InheritanceType.SINGLE_TABLE)
@DiscriminatorColumn(name = "animal_type")
public abstract class Animal2 {
  @Id
  @GeneratedValue(strategy = GenerationType.SEQUENCE)
  @Column(name = "animal2_id")
  private Long id;

  @Column(name = "animal_name")
  private String name;
  ...
}
```

```java
@Entity
@DiscriminatorValue("cat")
public class Cat2 extends Animal2 {
  private String breed;
  ...
}
```

```java
@Entity
@DiscriminatorValue("fish")
public class Fish2 extends Animal2{
  private String color;
  ...
}
```

```sql
Hibernate: insert into animal2 (animal_name,color,animal_type,animal2_id) values (?,?,'fish',?)
Hibernate: insert into animal2 (animal_name,breed,animal_type,animal2_id) values (?,?,'cat',?)
```

### Joined Table Strategy

- Keep the parent class property in joined table

```java
@Entity
@Table(name = "animal3")
@Inheritance(strategy = InheritanceType.JOINED)
public abstract class Animal3 {
  @Id
  @GeneratedValue(strategy = GenerationType.AUTO)
  @Column(name="animal3_id")
  private Long id;

  private String name;
  ...
}
```

```java
@Entity
@Table(name = "cat3")
public class Cat3 extends Animal3{
  @Column(name = "cat_name")
  private String catName;
  ...
}
```

```java
@Entity
@Table(name = "fish3")
public class Fish3 extends Animal3{
  @Column(name = "fish_name")
  private String fishName;
  ...
}
```

```sql
Hibernate: insert into animal3 (name,animal3_id) values (?,?)
Hibernate: insert into fish3 (fish_name,animal3_id) values (?,?)
Hibernate: insert into animal3 (name,animal3_id) values (?,?)
Hibernate: insert into cat3 (cat_name,animal3_id) values (?,?)
```

- If you need to change the animal3_id name into fish3_id in fish3 table then you can add: @PrimaryKeyJoinColumn(name = "fish3_id")

```java
@Entity
@Table(name = "fish3")
@PrimaryKeyJoinColumn(name = "fish3_id")
public class Fish3 extends Animal3{}
```

### Table per class strategy

- @Inheritance(strategy = InheritanceType.TABLE_PER_CLASS)
- if parent class is not abstract then hibernate create extra table for the parent class!

```java
@Entity
@Inheritance(strategy = InheritanceType.TABLE_PER_CLASS)
public abstract class Animal4 {
  @Id
  @GeneratedValue(strategy = GenerationType.AUTO)
  @Column(name = "animal4_id")
  private Long id;

  private String name;
  ...
}
```

```java
@Entity
@Table(name = "cat4")
public class Cat4 extends Animal4 {
  private String breed;

```

```java
@Entity
@Table(name = "fish4")
public class Fish4 extends Animal4 {
  private String color;
  ...
}
```

```java
Fish4 fish = new Fish4();
fish.setName("Golden Fish");
fish.setColor("Golden");
Cat4 cat = new Cat4();
cat.setName("Yellow Cat");
cat.setBreed("Street Cat");

em.persist(fish);
em.persist(cat);
```

```sql
Hibernate: select nextval('Animal4_SEQ')
Hibernate: select nextval('Animal4_SEQ')
Hibernate: insert into fish4 (name,color,animal4_id) values (?,?,?)
Hibernate: insert into cat4 (name,breed,animal4_id) values (?,?,?)
```

## Association class

### 1. ManyToMany, OneToMany, ManyToOne

### 2. Embeddable

- @Embedded, @Embeddable

```java
@Embeddable
public class B {
  private String x;
  private String y;
  ...
}
```

```java
@Entity
@Table(name = "a_table")
public class A {
  @Id
  @GeneratedValue(strategy = GenerationType.AUTO)
  @Column(name = "a_id")
  private Long id;

  @Embedded
  private B b;

  private String z;
  ...
}
```

```java
A a= new A();
B b= new B();

b.setX("x");
b.setY("y");

a.setZ("z");
a.setB(b);
em.persist(a);
```

```sql
Hibernate: insert into a_table (x,y,z,a_id) values (?,?,?,?)
```
