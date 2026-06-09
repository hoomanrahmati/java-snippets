## `@Lock`

[back](./transaction.md)

- "0" - No wait (fail immediately)
- "-1" - Wait indefinitely (database default behavior in many cases)
- "-2" The "Skip Locked" Behavior without raising error
- X number - Wait X milliseconds, then timeout
- Throws LockTimeoutException instantly without waiting

  `@QueryHints({@QueryHint(name = "jakarta.persistence.lock.timeout", value = "0")})`

```java
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @QueryHints({@QueryHint(name = "jakarta.persistence.lock.timeout", value = "0")})
    @Query("SELECT e FROM YourEntity e WHERE e.id = :id")
    Optional<YourEntity> findByIdWithLock(@Param("id") Long id);
```

### Using **TransactionTemplate** (No Separate Class Needed)

```java
@Service
public class RowProcessingService {

    @PersistenceContext
    private EntityManager entityManager;

    private final YourEntityRepository repository;
    private final TransactionTemplate transactionTemplate;

    public RowProcessingService(YourEntityRepository repository,
                                PlatformTransactionManager transactionManager) {
        this.repository = repository;
        // let spring inject transactionTemplate: this.transactionTemplate = transactionTemplate;
        this.transactionTemplate = new TransactionTemplate(transactionManager);
    }

    // this is also valid
    // public RowProcessingService(YourEntityRepository repository,
    //                             TransactionTemplate transactionTemplate) {
    //     this.repository = repository;
    //     this.transactionTemplate = transactionTemplate;
    // }

    public void processRows() {
        List<YourEntity> allRows = repository.findAll();

        for (YourEntity entity : allRows) {
            // Each iteration runs in its own transaction
            transactionTemplate.execute(status -> {
                try {
                    // Try to lock with NOWAIT
                    YourEntity lockedEntity = entityManager.find(
                        YourEntity.class,
                        entity.getId(),
                        LockModeType.PESSIMISTIC_WRITE,
                        Map.of("jakarta.persistence.lock.timeout", 0) // NOWAIT (throws if is locked)
                    );

                    if (lockedEntity != null) {
                        lockedEntity.setStatus("PROCESSED");
                        repository.save(lockedEntity);
                        System.out.println("Processed row: " + lockedEntity.getId());
                    }

                } catch (LockTimeoutException e) {
                    System.out.println("Row " + entity.getId() + " is locked, skipping...");
                }
                return null;
            });
        }
    }
}
```

### Using **`@Lock`** with Repository Method (Cleanest)

This avoids `@PersistenceContext` entirely and uses only Spring Data JPA:

```java
public interface YourEntityRepository extends JpaRepository<YourEntity, Long> {

    // Method to find and lock a single row with NOWAIT
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    // "0" - No wait (fail immediately)
    // Throws LockTimeoutException instantly without waiting
    @QueryHints({@QueryHint(name = "jakarta.persistence.lock.timeout", value = "0")})
    @Query("SELECT e FROM YourEntity e WHERE e.id = :id")
    Optional<YourEntity> findByIdWithLock(@Param("id") Long id);

    // Query all rows without lock
    @Query("SELECT e FROM YourEntity e")
    List<YourEntity> findAllWithoutLock();
}

@Service
public class RowProcessingService {

    private final YourEntityRepository repository;
    private final TransactionTemplate transactionTemplate;

    public RowProcessingService(YourEntityRepository repository,
                                PlatformTransactionManager transactionManager) {
        this.repository = repository;
        this.transactionTemplate = new TransactionTemplate(transactionManager);
    }

    public void processRows() {
        List<YourEntity> allRows = repository.findAllWithoutLock();

        for (YourEntity entity : allRows) {
            transactionTemplate.execute(status -> {
                try {
                    // Try to get the row with lock
                    Optional<YourEntity> lockedEntityOpt = repository.findByIdWithLock(entity.getId());

                    if (lockedEntityOpt.isPresent()) {
                        YourEntity lockedEntity = lockedEntityOpt.get();
                        lockedEntity.setStatus("PROCESSED");
                        repository.save(lockedEntity);
                        System.out.println("Processed: " + lockedEntity.getId());
                    }

                } catch (LockTimeoutException | PessimisticLockException e) {
                    System.out.println("Skipping locked row: " + entity.getId());
                }
                return null;
            });
        }
    }
}
```

### Self-Injection (Workaround for **@Transactional** internal calls)

If you really want to keep the `@Transactional` approach in the same class, you can **self-inject**:

```java
@Service
public class RowProcessingService {

    @Autowired
    private RowProcessingService self;  // Self-injection

    @PersistenceContext
    private EntityManager entityManager;

    private final YourEntityRepository repository;

    public RowProcessingService(YourEntityRepository repository) {
        this.repository = repository;
    }

    public void processRows() {
        List<YourEntity> allRows = repository.findAll();

        for (YourEntity entity : allRows) {
            // Call through self proxy - @Transactional WILL work
            self.processSingleRow(entity.getId());
        }
    }

    @Transactional  // Now this works because it's called via proxy
    public void processSingleRow(Long entityId) {
        try {
            YourEntity entity = entityManager.find(
                YourEntity.class,
                entityId,
                LockModeType.PESSIMISTIC_WRITE,
                Map.of("jakarta.persistence.lock.timeout", 0)
            );

            if (entity != null) {
                entity.setStatus("PROCESSED");
                repository.save(entity);
                System.out.println("Processed: " + entityId);
            }

        } catch (LockTimeoutException e) {
            System.out.println("Skipping locked row: " + entityId);
        }
    }
}
```

```java
    try{
        // First, read the entity without lock
        YourEntity entity = entityManager.find(YourEntity.class, entityId);
        // Then, explicitly try to lock it with NOWAIT
        entityManager.lock(entity, LockModeType.PESSIMISTIC_WRITE);
    } catch (LockTimeoutException e) {}

```

### Pessimistic Locking with SKIP LOCKED

The most efficient way to "go to the next row if it is locked" is to use a native SQL query with the `FOR UPDATE SKIP LOCKED` clause. You don't need to manually "unlock" the row; the lock is released automatically when your transaction commits or rolls back.

```java
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.transaction.annotation.Transactional;
import java.util.List;
import java.Optional;

public interface YourEntityRepository extends JpaRepository<YourEntity, Long> {

    @Query(value = "SELECT * FROM your_table WHERE your_condition = :condition FOR UPDATE SKIP LOCKED", nativeQuery = true)
    List<YourEntity> findAndLockAvailableRows(String condition);
}
```

Using `@Lock` with JPQL (for simpler queries)
If your query is simple and you prefer not to use native SQL, you can use Spring Data JPA's `@Lock` annotation. However, this method only works with JPQL, not native queries . It also requires you to set a query hint to enable the `SKIP LOCKED` behavior.

```java
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.QueryHints;
import jakarta.persistence.LockModeType;
import jakarta.persistence.QueryHint;

public interface YourEntityRepository extends JpaRepository<YourEntity, Long> {

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @QueryHints({ @QueryHint(name = "jakarta.persistence.lock.timeout", value = "-2") })
    @Query("select e from YourEntity e where e.condition = :condition")
    List<YourEntity> findAndLockAvailableRows(String condition);
}
```

```java
@Repository
public interface AccountRepository extends JpaRepository<Account, Long> {

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT a FROM Account a WHERE a.id = :id")
    Optional<Account> findByIdWithPessimisticLock(@Param("id") Long id);
}
```

### The Hybrid Approach: Database "SELECT FOR UPDATE SKIP LOCKED"

For scheduled jobs, PostgreSQL gives you a great alternative:

```java
// No distributed lock needed! Database handles it
@Transactional
public void processPendingJobs() {
    // This queries pending jobs and locks them atomically
    List<Job> jobs = entityManager.createNativeQuery(
        "SELECT * FROM jobs WHERE status = 'PENDING' " +
        "ORDER BY created_at LIMIT 10 " +
        "FOR UPDATE SKIP LOCKED",  // Key part!
        Job.class
    ).getResultList();

    for (Job job : jobs) {
        job.setStatus("PROCESSING");
        jobRepository.save(job);
        processJob(job);
    }
}

// Multiple instances can run this simultaneously!
// Each instance picks up different SKIPPED LOCKED rows
// Database handles the coordination
```

```java
// Repository with explicit locking:
public interface ProductRepository extends JpaRepository<Product, Long> {

    // Normal find - no lock
    Optional<Product> findById(Long id);

    // Explicit pessimistic lock - SELECT FOR UPDATE
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT p FROM Product p WHERE p.id = :id")
    Optional<Product> findByIdWithPessimisticLock(@Param("id") Long id);
}
```

### Pessimistic Locking (Database-Level)

Assumes conflicts will happen, locks the record immediately:

```java
@Repository
public interface AccountRepository extends JpaRepository<Account, Long> {

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT a FROM Account a WHERE a.id = :id")
    Optional<Account> findByIdWithPessimisticLock(@Param("id") Long id);
}

@Service
public class AccountService {

    @Transactional
    public void withdraw(Long accountId, BigDecimal amount) {
        // Acquires a database lock immediately - other transactions wait
        Account account = accountRepository.findByIdWithPessimisticLock(accountId)
            .orElseThrow();

        if (account.getBalance().compareTo(amount) >= 0) {
            account.setBalance(account.getBalance().subtract(amount));
            accountRepository.save(account);
        }
    }
}
```

### Optimistic Locking (Application-Level)

Assumes conflicts are rare, checks at commit time using a version column:

```java
@Entity
public class Account {
    @Id
    private Long id;
    private BigDecimal balance;

    @Version  // JPA automatically manages this
    private Integer version;
}

// If two transactions try to update simultaneously,
// the second one gets OptimisticLockException
```

### 1.5 Common **@Transactional** Pitfalls to Avoid

Using **@Transactional** is simple, but these mistakes will silently break it:

```java
@Service
public class UserService {

    // ❌ WRONG 1: Private method - proxy can't intercept
    @Transactional
    private void doPrivateWork() {
        // Transaction never starts
    }

    // ❌ WRONG 2: Internal call bypassing proxy
    @Transactional
    public void methodA() {
        this.methodB();  // @Transactional on methodB is IGNORED!
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void methodB() {
        // This will NOT run in a new transaction when called from methodA
    }

    // ✅ CORRECT: Self-injection pattern
    @Autowired
    private UserService self;

    @Transactional
    public void methodACorrect() {
        self.methodB();  // Goes through proxy, transaction works
    }

    // ❌ WRONG 3: Swallowing exceptions
    @Transactional
    public void deleteUser(Long id) {
        try {
            userRepository.deleteById(id);
            // Some operation that throws exception...
        } catch (Exception e) {
            log.error("Error", e);
            // Exception caught but not rethrown - NO ROLLBACK!
        }
    }

    // ✅ CORRECT: Re-throw or set rollback
    @Transactional
    public void deleteUserCorrect(Long id) {
        try {
            userRepository.deleteById(id);
            // Some operation that throws exception...
        } catch (Exception e) {
            log.error("Error", e);
            TransactionAspectSupport.currentTransactionStatus()
                .setRollbackOnly();  // Force rollback
            throw e;
        }
    }
}
```

---

## Locking Requires a Transaction

- Database-level requirement: Database locks are released when a transaction commits or rolls back. Without a transaction, the lock would be held only for a single statement.
- Hibernate requires it: EntityManager.lock() throws TransactionRequiredException if called outside a transaction.

### ✅ Correct approach

```java
@Service
public class UserService {

    @Transactional
    public void updateWithLock(Long userId) {
        // Pessimistic lock within transaction
        User user = userRepository.findByIdWithPessimisticLock(userId);
        user.setBalance(user.getBalance() - 100);
        // Lock released when transaction commits
    }
}
```

### ❌ Won't work

```java
@Service
public class UserService {
    // Missing @Transactional - will throw exception on lock attempt
    public void updateWithLock(Long userId) {
        User user = userRepository.findByIdWithPessimisticLock(userId);
        // Throws TransactionRequiredException
    }
}

@Repository
public interface UserRepository extends JpaRepository<User, Long> {
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select u from User u where u.id = :id")
    User findByIdWithPessimisticLock(@Param("id") Long id);
    // This also requires a transaction when called
}
```
