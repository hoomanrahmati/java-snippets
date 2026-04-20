### Transactional

[back](../README.md)

## The `@Transactional` Annotation – A Quick Reference

| Attribute                  | Type                           | Default           | Typical Values                                                                          | What it does                                                                                                                          |
| -------------------------- | ------------------------------ | ----------------- | --------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| **value**                  | `String`                       | _none_            | bean name of a `PlatformTransactionManager`                                             | The transaction manager that Spring should use. If omitted, Spring picks the _primary_ one.                                           |
| **propagation**            | `Propagation`                  | `REQUIRED`        | `REQUIRED`, `SUPPORTS`, `MANDATORY`, `REQUIRES_NEW`, `NOT_SUPPORTED`, `NEVER`, `NESTED` | How a new transaction relates to an existing one.                                                                                     |
| **isolation**              | `Isolation`                    | `DEFAULT`         | `READ_UNCOMMITTED`, `READ_COMMITTED`, `REPEATABLE_READ`, `SERIALIZABLE`                 | The database isolation level for the transaction.                                                                                     |
| **timeout**                | `int`                          | `-1` (no timeout) | any positive integer                                                                    | Maximum seconds a transaction may run before it is rolled back.                                                                       |
| **readOnly**               | `boolean`                      | `false`           | `true`/`false`                                                                          | Hint to the transaction manager that the transaction won’t modify data. Useful for optimisations (e.g. disabling auto‑commit checks). |
| **rollbackFor**            | `Class<? extends Throwable>[]` | _empty_           | any exception classes                                                                   | Exceptions that should trigger a rollback **in addition to** the default (`RuntimeException` & `Error`).                              |
| **noRollbackFor**          | `Class<? extends Throwable>[]` | _empty_           | any exception classes                                                                   | Exceptions that \*\*should NOT\*\* trigger a rollback, even if they are runtime.                                                      |
| **rollbackForClassName**   | `String[]`                     | _empty_           | fully qualified exception names                                                         | Same as `rollbackFor` but accepts class names for forward‑compatibility.                                                              |
| **noRollbackForClassName** | `String[]`                     | _empty_           | fully qualified exception names                                                         | Same as `noRollbackFor` but accepts class names.                                                                                      |

> **Tip:** In practice, the most frequently tuned attributes are `propagation`, `isolation`, `readOnly`, and
> `timeout`. The `rollbackFor` attributes are usually only needed for domain‑specific exception handling.

---

## 1. Propagation

Propagations dictate how a method behaves when called _inside_ or _outside_ an existing transaction.

| Value           | Meaning                                                                                                                                                                                   | Example                                                                               |
| --------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------- |
| `REQUIRED`      | Join an existing transaction; if none, start a new one.                                                                                                                                   | _Default_ – most common.                                                              |
| `SUPPORTS`      | Join an existing transaction if present; otherwise execute non‑transactionally. Useful for read‑only operations that may or may not be inside a larger transaction.                       |
| `MANDATORY`     | Must be called within a transaction; otherwise `TransactionRequiredException`.                                                                                                            | Enforce transaction scope on critical methods.                                        |
| `REQUIRES_NEW`  | Suspend any existing transaction and start a new one.                                                                                                                                     | Separate audit logs, or “do‑it‑or‑do‑not‑it” patterns.                                |
| `NOT_SUPPORTED` | Execute non‑transactionally; suspend any current transaction.                                                                                                                             | Long‑running read or external service calls that must not be part of the transaction. |
| `NEVER`         | Must not be called within a transaction; throws `IllegalTransactionStateException` if a transaction exists.                                                                               | For methods that can’t tolerate transaction context at all.                           |
| `NESTED`        | Execute within a _nested_ transaction (i.e., a savepoint). Requires a transaction manager that supports nested transactions (e.g., `DataSourceTransactionManager` with a JDBC 3+ driver). | Fine‑grained rollback for sub‑operations.                                             |

### Quick Rules of Thumb

| Scenario                                                                                                    | Recommended Propagation |
| ----------------------------------------------------------------------------------------------------------- | ----------------------- |
| Most service methods that need ACID guarantees                                                              | `REQUIRED`              |
| Read‑only queries that may be called from both transactional and non‑transactional contexts                 | `SUPPORTS`              |
| Logging or auditing that should **always** be independent of the main transaction                           | `REQUIRES_NEW`          |
| Operations that must not run inside a transaction (e.g., long‑running REST calls)                           | `NOT_SUPPORTED`         |
| A batch step that must abort if any part of it fails, but we also want to capture the error and re‑throw it | `NESTED` (if supported) |

---

## 2. Isolation

Isolation controls how visible the transaction’s changes are to other concurrent transactions. The values map
directly to JDBC isolation levels.

| Value              | JDBC Constant                                          | Behaviour                                                                            | When to use it                                                                             |
| ------------------ | ------------------------------------------------------ | ------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------ |
| `DEFAULT`          | `Connection.TRANSACTION_NONE` (driver‑defined default) | Uses the DB’s default isolation level                                                | (usually `READ_COMMITTED`). Good for most cases.                                           |
| `READ_UNCOMMITTED` | `Connection.TRANSACTION_READ_UNCOMMITTED`              | Allows dirty reads.                                                                  | Rarely needed; use only when performance is critical and you can tolerate dirty data.      |
| `READ_COMMITTED`   | `Connection.TRANSACTION_READ_COMMITTED`                | No dirty reads; can have non‑repeatable reads & phantom reads.                       | Default for many RDBMS (MySQL, PostgreSQL).                                                |
| `REPEATABLE_READ`  | `Connection.TRANSACTION_REPEATABLE_READ`               | Guarantees that if a row is read twice in the same transaction, it will be the same. | Useful for complex reporting where the same data must remain stable.                       |
| `SERIALIZABLE`     | `Connection.TRANSACTION_SERIALIZABLE`                  | Strictest – full isolation, behaves as if transactions are serialized.               | Rarely needed due to performance cost; use for highly concurrent, highly critical updates. |

### Practical Guidance

1. **Don’t set isolation unless you have a clear reason.**
   The overhead of higher isolation can be substantial, especially `SERIALIZABLE`.

2. **Read‑only methods usually keep the default or `READ_COMMITTED`.**
   In some cases you may use `READ_UNCOMMITTED` for bulk reads that tolerate stale data.

3. **Write‑heavy services: default isolation is often fine.**
   Spring will usually let the database manage locking.

4. **When you encounter “phantom reads” or “non‑repeatable reads” in tests, consider `REPEATABLE_READ`.**
   For example, a method that first reads a row, does some business logic, then updates it. If another transaction
   updates the row between reads, you might need stronger isolation.

---

## 3. `readOnly`

Setting `readOnly=true` is a _hint_ to the transaction manager and underlying database:

- **Optimisation**: Some databases can skip certain checks (e.g., avoid write locks) and may set the JDBC
  connection to read‑only.
- **Safety**: Hibernate, for example, will skip dirty checks and avoid flushes, which can be a performance win.
- **No enforcement**: Spring does **not** throw an exception if you accidentally write to a read‑only transaction.
  The database might ignore writes or throw an error depending on its configuration.

**Use‑cases**:

- Bulk read operations (e.g., report generators).
- Methods that only invoke DAO read methods.

**Caveat**: If you mix `readOnly=true` with `REQUIRES_NEW`, the nested transaction will still be read‑only unless
you override it.

---

## 4. `timeout`

Specifies how many seconds the transaction is allowed to run. After the timeout, Spring will trigger a rollback
and throw a `TransactionTimedOutException`.

- **Typical values**: 30‑60 seconds for user‑visible requests; lower for batch jobs, higher for long‑running
  analytics.
- **Why use it?**
  Protects the system from hanging transactions that might otherwise lock resources forever.

**Example**:

```java
@Transactional(timeout = 45) // 45 seconds
public void processLargeBatch() { … }
```

---

## 5. Rollback Control

Spring rolls back a transaction by default **only** for `RuntimeException` (unchecked) and `Error`. Checked
exceptions do not trigger a rollback unless you explicitly specify.

| Attribute                | Purpose                                                                                                                          |
| ------------------------ | -------------------------------------------------------------------------------------------------------------------------------- |
| `rollbackFor`            | Add exception classes that _should_ trigger a rollback.                                                                          |
| `noRollbackFor`          | Specify exception classes that _should not_ trigger a rollback (useful for domain‑specific errors that are considered “normal”). |
| `rollbackForClassName`   | Same as `rollbackFor` but accepts class names as `String`.                                                                       |
| `noRollbackForClassName` | Same as `noRollbackFor` but accepts class names as `String`.                                                                     |

**Example**:

```java
@Transactional(rollbackFor = {MyCheckedException.class})
public void doSomething() throws MyCheckedException { … }

@Transactional(noRollbackFor = {TransientDataAccessException.class})
public void updateWithRetry() { … }
```

### When to Use Rollback Customisation

- **Checked business exceptions** that should abort the transaction (e.g., `InsufficientBalanceException`).
- **Non‑critical errors** that are expected and should not roll back (e.g., `EmailSendFailedException`).
- **Retry‑able data access errors**: you might catch a `TransientDataAccessException`, retry, and only rollback if
  the retry fails.

---

## 6. Combining Attributes

You can combine any of these attributes on the same annotation:

```java
@Transactional(
    propagation = Propagation.REQUIRES_NEW,
    isolation = Isolation.REPEATABLE_READ,
    timeout = 120,
    readOnly = false,
    rollbackFor = { MyCheckedException.class }
)
public void criticalUpdate() { … }
```

### Common Patterns

| Pattern                                                                           | What it does                                                  |
| --------------------------------------------------------------------------------- | ------------------------------------------------------------- |
| **Service façade** (`REQUIRED` + default isolation)                               | Wraps business logic in a single transaction.                 |
| **Audit trail** (`REQUIRES_NEW` + `readOnly = true`)                              | Logs changes without affecting the main transaction.          |
| **Retryable DAO** (`SUPPORTS` + `noRollbackFor = {TransientDataAccessException}`) | DAO may be called both inside and outside a transaction.      |
| **Bulk import** (`REQUIRES_NEW` + `timeout = 600`)                                | Separate transaction that can run longer than the UI request. |

---

## 7. How Spring Implements `@Transactional`

1. **Proxy Generation**
   Spring creates a proxy (JDK dynamic proxy or CGLIB) around the bean. The proxy intercepts method calls.

2. **`TransactionInterceptor`**
   On each method call, the interceptor starts a transaction via the configured `PlatformTransactionManager`.

3. **Propagation Logic**
   The interceptor consults the current `TransactionStatus` and the chosen propagation rule to decide whether to:
   - Join the existing transaction.
   - Suspend it.
   - Start a new one.

4. **Isolation & Timeout**
   These settings are passed to the transaction manager, which typically delegates to the JDBC `Connection` or JTA
   transaction.

5. **Rollback Decision**
   After method execution, the interceptor checks for exceptions and applies the `rollbackFor` / `noRollbackFor`
   rules before deciding to commit or roll back.

---

## 8. Practical Tips & Gotchas

| Issue                                               | What to Watch For                                                                                                               |
| --------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| **Method visibility**                               | `@Transactional` works only on _public_ methods called from outside the bean. Internal self‑calls bypass the proxy.             |
| **Nested `@Transactional` inside a `REQUIRES_NEW`** | The inner call will still start a new transaction if it also uses `REQUIRES_NEW`.                                               |
| **Default `isolation`**                             | Even if you set `Isolation.DEFAULT`, your database may override it if it has a stricter default. Check your DB’s configuration. |
| **`readOnly` & Hibernate**                          | If you use JPA, set `@Transactional(readOnly = true)` on read‑only service methods; Hibernate will skip dirty checks and flush. |
| **Timeout & JTA**                                   | Some JTA providers ignore the `timeout` attribute; make sure your transaction manager supports it.                              |
| **Exception mapping**                               | If your data layer throws checked exceptions, Spring will not roll back unless you configure `rollbackFor`.                     |

---

## 9. Example: A Full‑Featured Service

```java
@Service
public class OrderService {

    @Autowired
    private OrderRepository orderRepo;
    @Autowired
    private PaymentGateway paymentGateway;

    /**
     * Place an order: this must be atomic.
     * - Use the default isolation (READ_COMMITTED).
     * - If any runtime exception occurs, rollback.
     * - If a checked exception (e.g., InsufficientFundsException) occurs, we also want a rollback.
     */
    @Transactional(rollbackFor = {InsufficientFundsException.class})
    public void placeOrder(Order order) throws InsufficientFundsException {
        orderRepo.save(order);                     // DB write
        paymentGateway.charge(order.getPayment()); // external call
        // If the payment fails, throw InsufficientFundsException → rollback
    }

    /**
     * Generate a sales report. No data modification, but we want it
     * to be consistent with the current snapshot of the DB.
     * We set readOnly=true to hint the persistence provider and DB.
     */
    @Transactional(readOnly = true)
    public SalesReport generateReport(Date from, Date to) {
        return orderRepo.findSalesBetween(from, to);
    }

    /**
     * Auditing: we want to log the order creation even if the main transaction fails.
     * Hence we use REQUIRES_NEW.
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void auditOrder(Order order) {
        auditRepo.log(order.getId(), "CREATED");
    }

    /**
     * A long‑running import that must not be interrupted.
     * Use a generous timeout and a new transaction.
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW, timeout = 300)
    public void importOrders(List<Order> orders) {
        for (Order o : orders) {
            orderRepo.save(o);
        }
    }
}
```

---

## 10. Summary

| Concept                         | Takeaway                                                             |
| ------------------------------- | -------------------------------------------------------------------- |
| **Propagation**                 | Controls how transactions nest. `REQUIRED` is default.               |
| **Isolation**                   | Map to JDBC levels; higher levels = stricter consistency but slower. |
| **readOnly**                    | Hint for optimization; don’t rely on enforcement.                    |
| **timeout**                     | Safeguard against runaway transactions.                              |
| **rollbackFor / noRollbackFor** | Customise rollback semantics beyond unchecked exceptions.            |
| **Combining**                   | Attributes are orthogonal; you can set any combination.              |
| **Proxy nature**                | Only public methods invoked from outside the bean are transactional. |

With this knowledge, you can tailor Spring’s transaction semantics to match your application’s consistency,
performance, and error‑handling requirements. Happy coding!
