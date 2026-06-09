### `@Transactional` `TransactionTemplate` `RabbitTemplate`

[back](../README.md)

## The Problem

```java
@Transactional  // ONE transaction for ALL jobs
public void processPendingJobs() {
    // This queries pending jobs and locks them atomically
    List<Job> jobs = entityManager.createNativeQuery(
        "SELECT * FROM jobs WHERE status = 'PENDING' " +
        "ORDER BY created_at LIMIT 10 " +
        "FOR UPDATE SKIP LOCKED",  // Key part!
        Job.class
    ).getResultList();

    for (Job job : jobs) {
        try {
            sendToQueue(job);  // If this fails for job #2
            job.setStatus("PROCESSED");
            jobRepository.save(job);
            // But job #1 is already updated! Can't rollback just job #2
        } catch (Exception e) {
            // Can't rollback only this job without rolling back everything
        }
    }
}
```

## Solutions

### Solution 1: **Programmatic Transaction Per Job** (Most Common)

```java
@Service
public class JobProcessorService {

    @Autowired
    private TransactionTemplate transactionTemplate;  // Spring's programmatic transactions

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Autowired
    private RabbitTemplate rabbitTemplate;  // or KafkaTemplate

    public void processPendingJobs() {
        while (true) {
            // Find and lock ONE job at a time (not in a transaction yet)
            Job job = findAndLockSingleJob();
            if (job == null) break;

            // Process each job in its own transaction
            boolean success = processJobInTransaction(job);

            if (!success) {
                // Handle failure - maybe move to dead letter queue
                moveToDeadLetterQueue(job);
            }
        }
    }

    private Job findAndLockSingleJob() {
        // This query runs outside transaction, just gets one row
        return jdbcTemplate.queryForObject(
            "SELECT * FROM jobs WHERE status = 'PENDING' " +
            "ORDER BY created_at LIMIT 1 " +
            "FOR UPDATE SKIP LOCKED",
            (rs, rowNum) -> new Job(rs),
            Job.class
        );
    }

    private boolean processJobInTransaction(Job job) {
        // Each job gets its own transaction
        return transactionTemplate.execute(status -> {
            try {
                // Re-lock the job within transaction
                Job lockedJob = jdbcTemplate.queryForObject(
                    "SELECT * FROM jobs WHERE id = ? FOR UPDATE",
                    (rs, rowNum) -> new Job(rs),
                    job.getId()
                );

                // Send to queue (this is the risky part)
                rabbitTemplate.convertAndSend("job.queue", lockedJob);

                // If we get here, queue send succeeded
                jdbcTemplate.update(
                    "UPDATE jobs SET status = 'PROCESSED', processed_at = NOW() " +
                    "WHERE id = ?",
                    lockedJob.getId()
                );

                return true;  // Commit transaction

            } catch (Exception e) {
                // Queue send failed - rollback this job only
                logger.error("Failed to process job: {}", job.getId(), e);

                // Optionally update status to FAILED (still within transaction)
                jdbcTemplate.update(
                    "UPDATE jobs SET status = 'FAILED', error_message = ? " +
                    "WHERE id = ?",
                    e.getMessage(), job.getId()
                );

                return false;  // Rollback transaction, but we already updated status
                // That update will also rollback if transaction rolls back!
                // So we need a different approach...
            }
        });
    }
}
```

### Solution 2: **Better Approach - Separate Try/Catch with Manual Updates**

```java
@Service
public class RobustJobProcessor {

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Autowired
    private RabbitTemplate rabbitTemplate;

    @Autowired
    private TransactionTemplate transactionTemplate;

    public void processPendingJobs() {
        while (true) {
            Job job = claimNextJob();  // Atomically claim one job
            if (job == null) break;

            boolean queueSuccess = false;
            try {
                // Send to queue first (outside transaction)
                rabbitTemplate.convertAndSend("job.queue", job);
                queueSuccess = true;
            } catch (Exception e) {
                logger.error("Queue send failed for job: {}", job.getId(), e);
            }

            // Now update job status based on queue success
            updateJobStatus(job, queueSuccess);
        }
    }

    private Job claimNextJob() {
        // Atomically claim one job - sets status to PROCESSING
        return jdbcTemplate.queryForObject(
            "UPDATE jobs SET status = 'PROCESSING', locked_at = NOW() " +
            "WHERE id = (SELECT id FROM jobs WHERE status = 'PENDING' " +
            "          ORDER BY created_at LIMIT 1 FOR UPDATE SKIP LOCKED) " +
            "RETURNING *",  // PostgreSQL returns updated row
            (rs, rowNum) -> new Job(rs)
        );
    }

    private void updateJobStatus(Job job, boolean queueSuccess) {
        // Separate transaction for status update
        transactionTemplate.execute(status -> {
            if (queueSuccess) {
                jdbcTemplate.update(
                    "UPDATE jobs SET status = 'COMPLETED', completed_at = NOW() " +
                    "WHERE id = ? AND status = 'PROCESSING'",
                    job.getId()
                );
            } else {
                // Either retry or mark as failed
                int retryCount = jdbcTemplate.queryForObject(
                    "SELECT retry_count FROM jobs WHERE id = ?",
                    Integer.class, job.getId()
                );

                if (retryCount < 3) {
                    jdbcTemplate.update(
                        "UPDATE jobs SET status = 'PENDING', retry_count = ?, " +
                        "last_error = ? WHERE id = ?",
                        retryCount + 1, "Queue send failed", job.getId()
                    );
                } else {
                    jdbcTemplate.update(
                        "UPDATE jobs SET status = 'DEAD_LETTER', last_error = ? " +
                        "WHERE id = ?",
                        "Queue send failed after 3 retries", job.getId()
                    );
                }
            }
            return null;
        });
    }
}
```

### Solution 3: **Using @Transactional with Propagation.REQUIRES_NEW**

```java
@Service
public class JobProcessorService {

    @Autowired
    private JobProcessorHelper helper;

    public void processPendingJobs() {
        List<Job> jobs = findAndLockJobs(10);  // Lock 10 jobs in main transaction

        for (Job job : jobs) {
            // Each job processed in separate transaction
            helper.processSingleJob(job);
        }
    }

    @Transactional  // Main transaction - releases locks after method ends
    public List<Job> findAndLockJobs(int limit) {
        return jdbcTemplate.query(
            "SELECT * FROM jobs WHERE status = 'PENDING' " +
            "ORDER BY created_at LIMIT ? FOR UPDATE SKIP LOCKED",
            (rs, rowNum) -> new Job(rs),
            limit
        );
    }
}

@Component
public class JobProcessorHelper {

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Autowired
    private RabbitTemplate rabbitTemplate;

    @Transactional(propagation = Propagation.REQUIRES_NEW)  // Separate transaction per job
    public void processSingleJob(Job job) {
        try {
            // Re-lock within this transaction
            jdbcTemplate.queryForObject(
                "SELECT 1 FROM jobs WHERE id = ? FOR UPDATE",
                Integer.class, job.getId()
            );

            // Send to queue
            rabbitTemplate.convertAndSend("job.queue", job);

            // Update status
            jdbcTemplate.update(
                "UPDATE jobs SET status = 'COMPLETED' WHERE id = ?",
                job.getId()
            );

        } catch (Exception e) {
            // This transaction rolls back, but job remains PENDING
            // Actually, the job is still locked from the main transaction!
            throw new RuntimeException("Failed to process job", e);
        }
    }
}
```

**⚠️ Issue with Solution 3:** The job remains locked by the main transaction until it commits. Not ideal.

### Solution 4: **Best Practice - Two-Phase Claim & Process**

```java
@Service
public class OptimalJobProcessor {

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Autowired
    private RabbitTemplate rabbitTemplate;

    @Autowired
    private TransactionTemplate transactionTemplate;

    public void processJobs() {
        while (true) {
            // Phase 1: Claim a job atomically (short transaction)
            Job job = claimJobWithShortLock();
            if (job == null) break;

            // Phase 2: Process without holding database lock
            boolean processed = processJob(job);

            if (!processed) {
                // Phase 3: Mark as failed (new transaction)
                markJobFailed(job);
            }
        }
    }

    private Job claimJobWithShortLock() {
        // Uses SKIP LOCKED to grab just one job and mark it as PROCESSING
        return transactionTemplate.execute(status -> {
            Job job = jdbcTemplate.queryForObject(
                "SELECT * FROM jobs WHERE status = 'PENDING' " +
                "ORDER BY created_at LIMIT 1 FOR UPDATE SKIP LOCKED",
                (rs, rowNum) -> new Job(rs)
            );

            if (job != null) {
                // Immediately mark as processing to release the lock
                jdbcTemplate.update(
                    "UPDATE jobs SET status = 'PROCESSING', " +
                    "locked_at = NOW(), locked_by = ? " +
                    "WHERE id = ?",
                    instanceId, job.getId()
                );
            }
            return job;
        });
    }

    private boolean processJob(Job job) {
        try {
            // Send to queue - NO database transaction holding lock
            rabbitTemplate.convertAndSend("job.queue", job);

            // Mark as completed in new transaction
            transactionTemplate.execute(status -> {
                jdbcTemplate.update(
                    "UPDATE jobs SET status = 'COMPLETED', completed_at = NOW() " +
                    "WHERE id = ? AND status = 'PROCESSING'",
                    job.getId()
                );
                return null;
            });
            return true;

        } catch (Exception e) {
            logger.error("Queue send failed for job: {}", job.getId(), e);
            return false;
        }
    }

    private void markJobFailed(Job job) {
        transactionTemplate.execute(status -> {
            int retryCount = jdbcTemplate.queryForObject(
                "SELECT retry_count FROM jobs WHERE id = ?",
                Integer.class, job.getId()
            );

            if (retryCount < 3) {
                jdbcTemplate.update(
                    "UPDATE jobs SET status = 'PENDING', retry_count = ?, " +
                    "last_error = ? WHERE id = ?",
                    retryCount + 1, "Queue send failed", job.getId()
                );
            } else {
                jdbcTemplate.update(
                    "UPDATE jobs SET status = 'DEAD_LETTER', last_error = ? " +
                    "WHERE id = ?",
                    "Failed after 3 retries", job.getId()
                );
            }
            return null;
        });
    }
}
```

## Key Insight

**The fundamental trick:** Don't hold the database lock while doing external operations (queue sends, API calls). Instead:

1. Use a **short transaction** to claim and mark the job as `PROCESSING`
2. **Release the lock** (by committing the short transaction)
3. Do the slow external operation without any lock
4. Use **another transaction** to mark as `COMPLETED` or `FAILED`

This way:

- ✅ Each job is processed exactly once (or retried)
- ✅ Queue send failure doesn't block other jobs
- ✅ No long-held database locks
- ✅ Better concurrency and throughput

## Database Table Design

```sql
CREATE TABLE jobs (
    id BIGSERIAL PRIMARY KEY,
    status VARCHAR(20) NOT NULL,  -- PENDING, PROCESSING, COMPLETED, FAILED, DEAD_LETTER
    retry_count INT DEFAULT 0,
    locked_at TIMESTAMP,
    locked_by VARCHAR(100),
    last_error TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    completed_at TIMESTAMP,

    INDEX idx_status_created (status, created_at)
);
```

**Bottom line:** Don't use `@Transactional` on the whole batch. Use short, targeted transactions with `SKIP LOCKED` to claim jobs, then process them outside transactions. This is the standard, battle-tested pattern for reliable job processing.

Would you like me to show you how to add dead letter queues, retry with exponential backoff, or monitoring for this setup?
