## Working with Queries

### Simple JPQL Query

```java
TypedQuery<BookType> q = em.createQuery("select bt from BookType bt", BookType.class);
List<BookType> result = q.getResultList();
result.forEach(System.out::println);
```

### Where Claus

```java
TypedQuery<BookType> q = em.createQuery("""
              select bt from BookType bt where
               subCode like :subCode and code like :code
        """, BookType.class);
q.setParameter("subCode", "2%");
q.setParameter("code", "12%");
List<BookType> result = q.getResultList();
result.forEach(System.out::println);
```
