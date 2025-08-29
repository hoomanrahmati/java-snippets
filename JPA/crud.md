## CRUD

[back](README.md)

### main method

```java
  EntityManagerFactory emf = Persistence.createEntityManagerFactory("library_persistence_unit");
  EntityManager em = emf.createEntityManager();
  try {
      em.getTransaction().begin();
      ...
      em.getTransaction().commit();
  }
  finally {
      em.close();
  }
```

### entities

```java
import jakarta.persistence.*;

@Entity
@Table(name = "book")
public class Book {
    @Id
    @GeneratedValue(strategy = GenerationType.AUTO)
    @Column(name = "book_id")
    private Long id;

    @Column(name="book_title")
    private String title;

    private String isbn;

    // getters and setters

    public String toString() {
        return "Book [id=" + id + ", title=" + title + ", isbn=" + isbn + "]";
    }
}
```

### Add (persist)

```java
  EntityManagerFactory emf = Persistence.createEntityManagerFactory("library_persistence_unit");
  EntityManager em = emf.createEntityManager();
  try {
      em.getTransaction().begin();
      Book book = new Book();
      book.setTitle("Java Hibernate");
      em.persist(book);
      em.getTransaction().commit();
  }
  finally {
      em.close();
  }
```

### Update

```java
  EntityManagerFactory emf = Persistence.createEntityManagerFactory("library_persistence_unit");
  EntityManager em = emf.createEntityManager();
  try {
      em.getTransaction().begin();
      Book book = em.find(Book.class, 1);
      book.setIsbn("123-456");
      em.getTransaction().commit();
  }
  finally {
      em.close();
  }
```

### Update (merge)

```java
  em.getTransaction().begin();
  Book book = new Book();
  book.setId(1L);
  book.setTitle("New Title");
  em.merge(book);
  em.getTransaction().commit();

```

Hibernate: select b1_0.book_id,b1_0.isbn,b1_0.book_title from book b1_0 where b1_0.book_id=?

Hibernate: update book set isbn=?,book_title=? where book_id=?

Book [id=1, title=New Title, isbn=null]

- before merge the isbn has value, but after merge the isbn is null

## Composite Primary Key on a Entity Class

1. **IdClass:**

- @IdClass(BookTypeKey.class)
- Add @Id for all unique composition
- The primary type should implements Serializable

```java
public class BookTypeKey implements Serializable {
  private String code;
  private String subCode;
  // getters and setters
}

@Entity
@Table(name = "book_type")
@IdClass(BookTypeKey.class)
public class BookType {
  @Id
  @Column(name = "type_code")
  private String code;

  @Id
  @Column(name = "type_subcode")
  private String subCode;

  @Column(name="type_name")
  private String name;
  // getters, setters and toString ...
}
```

2. **Embeddable Class:**

- @Embeddable (Embeddable must be Serializable)
- @EmbeddedId

```java
@Embeddable
public class ItemKey implements Serializable {
  @Column(name = "item_id")
  private Long itemId;

  @Column(name = "item_number")
  private Integer itemNumber;
  // getters and setters
}

...

@Entity
@Table(name = "item")
public class Item {
  @EmbeddedId
  private ItemKey id;

  @Column(name = "item_name", unique = true, nullable = false)
  private String name;
  ...
}
```
