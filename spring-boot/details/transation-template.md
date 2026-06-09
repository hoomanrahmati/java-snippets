## `TransactionTemplate`

[back](./transaction.md)

### Inject it:

### 1.

```java
@Service
public class UserService {
    private final TransactionTemplate transactionTemplate;

    // Spring Boot already provides a TransactionTemplate bean
    public UserService(TransactionTemplate transactionTemplate) {
        this.transactionTemplate = transactionTemplate;
    }
}
```

### `OR`

### 2.

```java
@Service
public class UserService {
    private final TransactionTemplate transactionTemplate;

    // Your approach - manually creating TransactionTemplate
    public UserService(PlatformTransactionManager transactionManager) {
        this.transactionTemplate = new TransactionTemplate(transactionManager);
    }
}
```

### `OR`

### 3.

```java
  @Autowired
  private TransactionTemplate outerTemplate;
```

---

Here's a comprehensive reference table for all methods available on the `TransactionStatus` interface in Spring:

## TransactionStatus Method Reference Table

| Method               | Return Type | Description                                                                       | When to Use                                                                                    |
| -------------------- | ----------- | --------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| `isNewTransaction()` | `boolean`   | Returns `true` if the transaction is new (not an existing one in a nested call)   | To check if this transaction was freshly started or if you're participating in an existing one |
| `hasSavepoint()`     | `boolean`   | Returns `true` if the current transaction has a savepoint                         | To check if you can rollback to a savepoint (nested transactions)                              |
| `setRollbackOnly()`  | `void`      | Marks the transaction for rollback (forces rollback even if no exception occurs)  | When business conditions require rollback without throwing an exception                        |
| `isRollbackOnly()`   | `boolean`   | Returns `true` if the transaction has been marked for rollback                    | To check if someone else has marked the transaction for rollback                               |
| `flush()`            | `void`      | Flushes all pending changes to the database                                       | To force persistence provider to synchronize with database before commit                       |
| `isCompleted()`      | `boolean`   | Returns `true` if the transaction is already completed (committed or rolled back) | To verify transaction is still active before performing operations                             |

## Detailed Usage Examples

### 1. **setRollbackOnly() & isRollbackOnly()**

```java
transactionTemplate.execute(status -> {
    // Perform some operations
    userRepository.save(user1);

    // Check business condition
    if (user1.getAge() < 18) {
        status.setRollbackOnly();  // Mark for rollback
        return "User underage - rolling back";
    }

    // This won't execute if rollback marked
    userRepository.save(user2);

    // Check if someone else marked it
    if (status.isRollbackOnly()) {
        System.out.println("Transaction will rollback!");
    }

    return "Success";
});
```

### 2. **isNewTransaction()**

```java
@Service
public class NestedService {

    @Autowired
    private TransactionTemplate outerTemplate;

    @Autowired
    private TransactionTemplate innerTemplate;

    public void demonstrateNewTransaction() {
        outerTemplate.execute(outerStatus -> {
            System.out.println("Is outer new? " + outerStatus.isNewTransaction()); // true

            // Inner with REQUIRES_NEW
            innerTemplate.setPropagationBehavior(TransactionDefinition.PROPAGATION_REQUIRES_NEW);
            innerTemplate.execute(innerStatus -> {
                System.out.println("Is inner new? " + innerStatus.isNewTransaction()); // true
                return null;
            });

            // must return something, even null
            return null;
        });
    }

    public void demonstrateParticipating() {
        outerTemplate.execute(outerStatus -> {
            System.out.println("Is outer new? " + outerStatus.isNewTransaction()); // true

            // Inner with REQUIRED (default)
            innerTemplate.setPropagationBehavior(TransactionDefinition.PROPAGATION_REQUIRED);
            innerTemplate.execute(innerStatus -> {
                System.out.println("Is inner new? " + innerStatus.isNewTransaction()); // false - participates in outer
                return null;
            });

            return null;
        });
    }
}
```

### 3. **hasSavepoint()** (for nested transactions)

```java
transactionTemplate.execute(status -> {
    System.out.println("Has savepoint? " + status.hasSavepoint()); // false initially

    // Nested transaction using PROPAGATION_NESTED
    TransactionTemplate nestedTemplate = new TransactionTemplate(transactionManager);
    nestedTemplate.setPropagationBehavior(TransactionDefinition.PROPAGATION_NESTED);

    nestedTemplate.execute(nestedStatus -> {
        System.out.println("Has savepoint? " + nestedStatus.hasSavepoint()); // true
        // Can rollback only nested part
        if (someCondition()) {
            nestedStatus.setRollbackOnly();
        }
        return null;
    });

    return null;
});
```

### 4. **flush()**

```java
transactionTemplate.execute(status -> {
    // Save entities but don't flush immediately
    userRepository.save(user1);
    userRepository.save(user2);

    // Force flush to catch constraint violations early
    try {
        status.flush();  // Forces Hibernate/JPA to synchronize with DB
    } catch (DataIntegrityViolationException e) {
        status.setRollbackOnly();
        throw e;
    }

    return null;
});
```

### 5. **isCompleted()**

```java
transactionTemplate.execute(status -> {
    System.out.println("Before operations, completed? " + status.isCompleted()); // false

    performOperations();

    System.out.println("After operations, completed? " + status.isCompleted()); // false

    return null;
    // After commit, can't access status (it's detached)
});
```

## Combined Example - Using Multiple Methods

```java
@Service
public class OrderProcessingService {

    public Order processOrder(OrderDto dto) {
        return transactionTemplate.execute(status -> {
            // Check if this is a new transaction or participating
            if (status.isNewTransaction()) {
                log.info("Starting new transaction for order: {}", dto.getOrderId());
            } else {
                log.info("Participating in existing transaction for order: {}", dto.getOrderId());
            }

            try {
                // Save order
                Order order = orderRepository.save(convertToOrder(dto));

                // Flush to generate ID and catch constraint violations early
                status.flush();

                // Update inventory (could fail)
                inventoryService.decreaseStock(dto.getProductId(), dto.getQuantity());

                // Business rule: orders over $1000 need approval
                if (order.getTotalAmount() > 1000 && !dto.isApproved()) {
                    log.warn("Order {} over $1000 without approval - marking rollback", order.getId());
                    status.setRollbackOnly();

                    // Verify it's marked
                    if (status.isRollbackOnly()) {
                        log.info("Transaction marked for rollback - changes will be reverted");
                    }

                    throw new UnapprovedOrderException("Order requires approval");
                }

                return order;

            } catch (InsufficientStockException e) {
                // Mark rollback and rethrow
                status.setRollbackOnly();
                throw e;
            }
        });
    }
}
```

## Quick Decision Guide

| If you need to...                               | Use this method      |
| ----------------------------------------------- | -------------------- |
| Force a rollback without throwing an exception  | `setRollbackOnly()`  |
| Check if transaction will rollback              | `isRollbackOnly()`   |
| Know if you're in a new vs existing transaction | `isNewTransaction()` |
| Check if nested transaction has a savepoint     | `hasSavepoint()`     |
| Force database synchronization mid-transaction  | `flush()`            |
| Verify transaction is still active              | `isCompleted()`      |

## Important Notes

1. **After commit/rollback**: The `TransactionStatus` object becomes detached - don't use its methods after `execute()` returns
2. **Thread safety**: `TransactionStatus` is not thread-safe - don't share across threads
3. **Flush behavior**: `flush()` behavior depends on your persistence provider (JPA/Hibernate/plain JDBC)
4. **Savepoints**: Only available when using `PROPAGATION_NESTED` or JDBC savepoints

This should give you a complete reference for all `TransactionStatus` methods available in Spring!
