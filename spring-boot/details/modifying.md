# `@Modifying`, `flushAutomatically` and `clearAutomatically`

[back](./transaction.md)

## For UPDATE, DELETE, or INSERT operations with custom `@Query`, you need `@Modifying`. Let me explain all the options available.

## @Modifying Options

### 1. **`clearAutomatically`** (default: false)

**What it does:** Clears the persistence context after the modifying query executes.

**Why you need it:** Without this, the EntityManager still holds old entity instances in its cache (1st level cache), even though the database has been updated.

```java
@Modifying
@Query("UPDATE User u SET u.name = :newName WHERE u.id = :id")
int updateUserName(@Param("id") Long id, @Param("newName") String newName);
```

**Problem without `clearAutomatically = true`:**

```java
@Transactional
public void problemExample() {
    User user = userRepository.findById(1L).get();  // Loaded in persistence context
    userRepository.updateUserName(1L, "New Name");  // Database updated
    User sameUser = userRepository.findById(1L).get();
    // ❌ Returns OLD cached entity with old name! Not from database!
}
```

**Solution with `clearAutomatically = true`:**

```java
@Modifying(clearAutomatically = true)
@Query("UPDATE User u SET u.name = :newName WHERE u.id = :id")
int updateUserName(@Param("id") Long id, @Param("newName") String newName);
```

### 2. **`flushAutomatically`** (default: false)

**What it does:** Flushes pending changes to the database BEFORE executing the modifying query.

**Why you need it:** Ensures all pending entity changes are synchronized with the database before your UPDATE/DELETE runs.

```java
@Modifying(flushAutomatically = true)
@Query("DELETE FROM User u WHERE u.status = 'INACTIVE'")
int deleteInactiveUsers();
```

**Without `flushAutomatically`:**

```java
@Transactional
public void problemExample() {
    User user = userRepository.findById(1L).get();
    user.setStatus("INACTIVE");  // Pending change, not yet in database
    userRepository.deleteInactiveUsers();  // ❌ Might not delete user because
                                           // status in DB is still 'ACTIVE'
}
```

**With `flushAutomatically = true`:**

```java
@Transactional
public void solutionExample() {
    User user = userRepository.findById(1L).get();
    user.setStatus("INACTIVE");  // Pending change
    userRepository.deleteInactiveUsers();
    // ✅ Flushes pending changes first, so user status is 'INACTIVE' in DB,
    // then deletes the user
}
```

## Combining Both Options

```java
@Modifying(clearAutomatically = true, flushAutomatically = true)
@Query("UPDATE User u SET u.status = 'DELETED' WHERE u.lastLoginDate < :date")
int archiveOldUsers(@Param("date") LocalDateTime date);
```

## Complete Example Showing the Difference

```java
@Service
public class UserService {

    @Autowired
    private UserRepository userRepository;

    @Transactional
    public void demonstrateClearAutomatically() {
        // Setup
        User user = new User("John", "ACTIVE");
        userRepository.save(user);

        // Update using modifying query WITHOUT clearAutomatically
        userRepository.updateUserName(user.getId(), "John Updated");

        User fetched = userRepository.findById(user.getId()).get();
        System.out.println(fetched.getName());
        // ❌ Prints "John" (old value from cache), not "John Updated"

        // Fix: Use clearAutomatically = true
        userRepository.updateUserNameWithClear(user.getId(), "John Updated Again");

        User fetched2 = userRepository.findById(user.getId()).get();
        System.out.println(fetched2.getName());
        // ✅ Prints "John Updated Again" (fresh from database)
    }

    @Transactional
    public void demonstrateFlushAutomatically() {
        // Save user as ACTIVE
        User user = new User("Jane", "ACTIVE");
        userRepository.save(user);

        // Modify entity (pending change)
        user.setStatus("INACTIVE");

        // Delete inactive users WITHOUT flush
        int deleted = userRepository.deleteInactiveUsersWithoutFlush();
        System.out.println("Deleted: " + deleted);  // ❌ Prints 0 (status still ACTIVE in DB)

        // Delete inactive users WITH flush
        int deleted2 = userRepository.deleteInactiveUsersWithFlush();
        System.out.println("Deleted: " + deleted2);  // ✅ Prints 1 (pending changes flushed)
    }
}
```

## Repository Methods

```java
@Repository
public interface UserRepository extends JpaRepository<User, Long> {

    // Neither option
    @Modifying
    @Query("UPDATE User u SET u.name = :name WHERE u.id = :id")
    int updateUserName(@Param("id") Long id, @Param("name") String name);

    // Only clear
    @Modifying(clearAutomatically = true)
    @Query("UPDATE User u SET u.name = :name WHERE u.id = :id")
    int updateUserNameWithClear(@Param("id") Long id, @Param("name") String name);

    // Only flush
    @Modifying(flushAutomatically = true)
    @Query("DELETE FROM User u WHERE u.status = 'INACTIVE'")
    int deleteInactiveUsersWithoutFlush();

    // Both
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("DELETE FROM User u WHERE u.status = 'INACTIVE'")
    int deleteInactiveUsersWithFlush();
}
```

## Common Use Cases

| Scenario                                          | Use `clearAutomatically` | Use `flushAutomatically` |
| ------------------------------------------------- | ------------------------ | ------------------------ |
| Simple UPDATE with no subsequent reads            | ❌ No                    | ❌ No                    |
| UPDATE then immediate SELECT of same entities     | ✅ Yes                   | ❌ No                    |
| DELETE based on pending entity changes            | ❌ No                    | ✅ Yes                   |
| Complex batch operations with mixed entity states | ✅ Yes                   | ✅ Yes                   |

## Performance Consideration

- **`clearAutomatically`** - Clears cache, forcing database hits for subsequent queries (slower but consistent)
- **`flushAutomatically`** - Forces immediate SQL execution (may impact performance if overused)

**Best practice:** Only use these when you actually need them for data consistency!
