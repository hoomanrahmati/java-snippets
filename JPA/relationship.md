## Entity Relationships

[back](README.md)

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

Hibernate: insert into post (title,post_id) values (?,?)

Hibernate: insert into post_comment (comment,post_post_id,post_comment_id) values (?,?,?)

Hibernate: insert into post_comment (comment,post_post_id,post_comment_id) values (?,?,?)

### ManyToMany Relationship

### Unidirectional Relationship vs. Bidirectional Relationship
