## Master Detail Entites

[back](./README.md)

[CRUD](#2crud)

[More](#3more)

# 1

This is a very common interview and real-world scenario because it demonstrates:

- One-to-Many relationship
- Transactions
- Cascading
- DTO mapping
- JPA persistence
- Service layer architecture

I'll create a simple Spring Boot example using **Spring Data JPA** (which internally uses `EntityManager`). After that, I'll also show how to do exactly the same thing with `EntityManager.persist()`.

---

# Project Structure

```
src
 ├── controller
 │      InvoiceController.java
 │
 ├── dto
 │      CreateInvoiceRequest.java
 │      InvoiceItemRequest.java
 │
 ├── entity
 │      Invoice.java
 │      InvoiceItem.java
 │
 ├── repository
 │      InvoiceRepository.java
 │
 ├── service
 │      InvoiceService.java
 │
 └── Application.java
```

---

# Invoice Entity

```java
package com.example.entity;

import jakarta.persistence.*;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;

@Entity
@Table(name = "invoice")
public class Invoice {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private String customerName;

    private BigDecimal totalAmount;

    @OneToMany(
            mappedBy = "invoice",
            cascade = CascadeType.ALL,
            orphanRemoval = true
    )
    private List<InvoiceItem> items = new ArrayList<>();

    public void addItem(InvoiceItem item) {
        items.add(item);
        item.setInvoice(this);
    }

    // getters and setters

    public Long getId() {
        return id;
    }

    public String getCustomerName() {
        return customerName;
    }

    public BigDecimal getTotalAmount() {
        return totalAmount;
    }

    public List<InvoiceItem> getItems() {
        return items;
    }

    public void setCustomerName(String customerName) {
        this.customerName = customerName;
    }

    public void setTotalAmount(BigDecimal totalAmount) {
        this.totalAmount = totalAmount;
    }
}
```

---

# InvoiceItem Entity

```java
package com.example.entity;

import jakarta.persistence.*;

import java.math.BigDecimal;

@Entity
@Table(name = "invoice_item")
public class InvoiceItem {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private String productName;

    private Integer quantity;

    private BigDecimal price;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "invoice_id")
    private Invoice invoice;

    // getters and setters

    public Long getId() {
        return id;
    }

    public String getProductName() {
        return productName;
    }

    public Integer getQuantity() {
        return quantity;
    }

    public BigDecimal getPrice() {
        return price;
    }

    public Invoice getInvoice() {
        return invoice;
    }

    public void setProductName(String productName) {
        this.productName = productName;
    }

    public void setQuantity(Integer quantity) {
        this.quantity = quantity;
    }

    public void setPrice(BigDecimal price) {
        this.price = price;
    }

    public void setInvoice(Invoice invoice) {
        this.invoice = invoice;
    }
}
```

---

# DTOs

## CreateInvoiceRequest

```java
package com.example.dto;

import java.util.List;

public class CreateInvoiceRequest {

    private String customerName;

    private List<InvoiceItemRequest> items;

    public String getCustomerName() {
        return customerName;
    }

    public List<InvoiceItemRequest> getItems() {
        return items;
    }

    public void setCustomerName(String customerName) {
        this.customerName = customerName;
    }

    public void setItems(List<InvoiceItemRequest> items) {
        this.items = items;
    }
}
```

---

## InvoiceItemRequest

```java
package com.example.dto;

import java.math.BigDecimal;

public class InvoiceItemRequest {

    private String productName;

    private Integer quantity;

    private BigDecimal price;

    public String getProductName() {
        return productName;
    }

    public Integer getQuantity() {
        return quantity;
    }

    public BigDecimal getPrice() {
        return price;
    }

    public void setProductName(String productName) {
        this.productName = productName;
    }

    public void setQuantity(Integer quantity) {
        this.quantity = quantity;
    }

    public void setPrice(BigDecimal price) {
        this.price = price;
    }
}
```

---

# Repository

```java
package com.example.repository;

import com.example.entity.Invoice;
import org.springframework.data.jpa.repository.JpaRepository;

public interface InvoiceRepository
        extends JpaRepository<Invoice, Long> {
}
```

---

# Service

```java
package com.example.service;

import com.example.dto.CreateInvoiceRequest;
import com.example.dto.InvoiceItemRequest;
import com.example.entity.Invoice;
import com.example.entity.InvoiceItem;
import com.example.repository.InvoiceRepository;
import jakarta.transaction.Transactional;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;

@Service
public class InvoiceService {

    private final InvoiceRepository invoiceRepository;

    public InvoiceService(InvoiceRepository invoiceRepository) {
        this.invoiceRepository = invoiceRepository;
    }

    @Transactional
    public Long createInvoice(CreateInvoiceRequest request) {

        Invoice invoice = new Invoice();
        invoice.setCustomerName(request.getCustomerName());

        BigDecimal total = BigDecimal.ZERO;

        for (InvoiceItemRequest dto : request.getItems()) {

            InvoiceItem item = new InvoiceItem();
            item.setProductName(dto.getProductName());
            item.setQuantity(dto.getQuantity());
            item.setPrice(dto.getPrice());

            invoice.addItem(item);

            total = total.add(
                    dto.getPrice()
                       .multiply(BigDecimal.valueOf(dto.getQuantity()))
            );
        }

        invoice.setTotalAmount(total);

        invoiceRepository.save(invoice);

        return invoice.getId();
    }

}
```

Notice there is **only one save()**.

Because of

```java
cascade = CascadeType.ALL
```

Hibernate automatically inserts

```
INSERT invoice

INSERT invoice_item

INSERT invoice_item

INSERT invoice_item
```

inside one transaction.

---

# Controller

```java
package com.example.controller;

import com.example.dto.CreateInvoiceRequest;
import com.example.service.InvoiceService;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/invoices")
public class InvoiceController {

    private final InvoiceService service;

    public InvoiceController(InvoiceService service) {
        this.service = service;
    }

    @PostMapping
    public Long createInvoice(
            @RequestBody CreateInvoiceRequest request) {

        return service.createInvoice(request);
    }
}
```

---

# JSON Request

```json
{
  "customerName": "John",
  "items": [
    {
      "productName": "Laptop",
      "quantity": 2,
      "price": 1200
    },
    {
      "productName": "Mouse",
      "quantity": 3,
      "price": 30
    }
  ]
}
```

---

# What Hibernate Does

Suppose generated id is **5**

It executes something similar to

```sql
insert into invoice
(customer_name,total_amount)
values
('John',2490);

insert into invoice_item
(product_name,quantity,price,invoice_id)
values
('Laptop',2,1200,5);

insert into invoice_item
(product_name,quantity,price,invoice_id)
values
('Mouse',3,30,5);
```

---

# The Same Example Using EntityManager

Instead of a repository, inject the `EntityManager`:

```java
@Service
public class InvoiceService {

    @PersistenceContext
    private EntityManager entityManager;

    @Transactional
    public Long createInvoice(CreateInvoiceRequest request) {

        Invoice invoice = new Invoice();
        invoice.setCustomerName(request.getCustomerName());

        BigDecimal total = BigDecimal.ZERO;

        for (InvoiceItemRequest dto : request.getItems()) {

            InvoiceItem item = new InvoiceItem();
            item.setProductName(dto.getProductName());
            item.setQuantity(dto.getQuantity());
            item.setPrice(dto.getPrice());

            invoice.addItem(item);

            total = total.add(
                    dto.getPrice()
                            .multiply(BigDecimal.valueOf(dto.getQuantity()))
            );
        }

        invoice.setTotalAmount(total);

        entityManager.persist(invoice);

        return invoice.getId();
    }
}
```

This works because:

1. `persist(invoice)` makes the `Invoice` entity managed.
2. The `InvoiceItem` entities are reachable through the `items` collection.
3. Since the relationship uses `CascadeType.PERSIST` (included in `CascadeType.ALL`), Hibernate automatically persists each `InvoiceItem`.
4. At transaction commit (or when the persistence context is flushed), Hibernate generates the `INSERT` statements for the invoice first and then the invoice items with the correct foreign key.

---

## Why use `addItem()` instead of `invoice.getItems().add(item)`?

A common beginner mistake is:

```java
invoice.getItems().add(item);
```

This only updates the parent collection. The owning side of the relationship is `InvoiceItem.invoice` (because of `@ManyToOne`), so Hibernate uses that field to determine the foreign key. If you don't set it:

```java
item.setInvoice(invoice);
```

the `invoice_id` may remain `NULL` (or the relationship won't be established correctly).

That's why the helper method encapsulates both updates:

```java
public void addItem(InvoiceItem item) {
    items.add(item);
    item.setInvoice(this);
}
```

This keeps both sides of the bidirectional relationship synchronized and avoids subtle bugs.

---

# 2(CRUD)

**Create + Update + Delete** demonstrates some of the most important JPA concepts:

- Persistence Context
- Managed vs Detached entities
- Dirty Checking
- Cascade
- Orphan Removal
- Transactions

Let's extend the previous example.

---

# Update Invoice

Suppose the client sends:

```json
{
  "customerName": "John Smith",
  "items": [
    {
      "productName": "Laptop",
      "quantity": 1,
      "price": 1000
    },
    {
      "productName": "Keyboard",
      "quantity": 2,
      "price": 50
    }
  ]
}
```

Assume invoice **5** already exists.

---

## Controller

```java
@PutMapping("/{id}")
public Long updateInvoice(
        @PathVariable Long id,
        @RequestBody CreateInvoiceRequest request) {

    return service.updateInvoice(id, request);
}
```

---

## Service

```java
@Transactional
public Long updateInvoice(Long id, CreateInvoiceRequest request) {

    Invoice invoice = invoiceRepository.findById(id)
            .orElseThrow(() -> new RuntimeException("Invoice not found"));

    invoice.setCustomerName(request.getCustomerName());

    // remove existing items
    invoice.getItems().clear();

    BigDecimal total = BigDecimal.ZERO;

    for (InvoiceItemRequest dto : request.getItems()) {

        InvoiceItem item = new InvoiceItem();

        item.setProductName(dto.getProductName());
        item.setQuantity(dto.getQuantity());
        item.setPrice(dto.getPrice());

        invoice.addItem(item);

        total = total.add(
                dto.getPrice()
                        .multiply(BigDecimal.valueOf(dto.getQuantity()))
        );
    }

    invoice.setTotalAmount(total);

    // No save() required

    return invoice.getId();
}
```

Notice something interesting.

There is **no**

```java
invoiceRepository.save(invoice);
```

Why?

Because the invoice is already **managed**.

JPA automatically detects changes.

This is called **Dirty Checking**.

When the transaction commits:

```
Invoice (Managed)

↓ customerName changed

↓ totalAmount changed

↓ items changed

Commit

↓

Hibernate automatically executes SQL
```

---

## SQL Generated

Suppose old items were

```
Laptop
Mouse
Monitor
```

New items

```
Laptop
Keyboard
```

Hibernate will execute something similar to

```sql
update invoice
set customer_name='John Smith',
    total_amount=1100
where id=5;

delete from invoice_item
where invoice_id=5;

insert into invoice_item(...)

insert into invoice_item(...)
```

because

```java
orphanRemoval = true
```

tells Hibernate

> "Any child removed from the collection should also be deleted."

---

# Delete Invoice

Controller

```java
@DeleteMapping("/{id}")
public void deleteInvoice(@PathVariable Long id) {
    service.deleteInvoice(id);
}
```

---

## Service

```java
@Transactional
public void deleteInvoice(Long id) {

    Invoice invoice = invoiceRepository.findById(id)
            .orElseThrow(() -> new RuntimeException("Invoice not found"));

    invoiceRepository.delete(invoice);
}
```

That's all.

---

Generated SQL

```sql
delete
from invoice_item
where invoice_id=5;

delete
from invoice
where id=5;
```

The children are deleted first because

```
cascade = CascadeType.ALL
```

and because of the foreign key constraint.

---

# What Happens Inside JPA?

Suppose

```
Invoice

id = 5
```

### Before update

```
Persistence Context

Invoice
 id = 5
 customer = John

Items

Laptop

Mouse
```

Everything is **Managed**.

---

You do

```java
invoice.setCustomerName("John Smith");
```

JPA remembers

```
Original

customer = John

Current

customer = John Smith
```

No SQL yet.

---

Then

```java
invoice.getItems().clear();
```

Because

```java
orphanRemoval=true
```

Hibernate marks every child as deleted.

Still no SQL.

---

Then

```java
invoice.addItem(...)
```

New children become Managed.

Still no SQL.

---

Commit transaction

↓

Hibernate compares snapshots

↓

Generates SQL

↓

Done.

---

# More Efficient Update (Recommended)

The previous update strategy is simple but inefficient because it deletes all items and recreates them, even if only one item changed.

A better approach is to include the item IDs in the DTO and update only what's necessary.

## Update DTOs

```java
public class UpdateInvoiceRequest {

    private String customerName;
    private List<UpdateInvoiceItemRequest> items;

    // getters/setters
}
```

```java
public class UpdateInvoiceItemRequest {

    private Long id;          // null for new items
    private String productName;
    private Integer quantity;
    private BigDecimal price;

    // getters/setters
}
```

## Service Logic

```java
@Transactional
public void updateInvoice(Long invoiceId, UpdateInvoiceRequest request) {

    Invoice invoice = invoiceRepository.findById(invoiceId)
            .orElseThrow();

    invoice.setCustomerName(request.getCustomerName());

    // Existing items indexed by ID
    Map<Long, InvoiceItem> existingItems = invoice.getItems().stream()
            .collect(Collectors.toMap(InvoiceItem::getId, Function.identity()));

    BigDecimal total = BigDecimal.ZERO;

    for (UpdateInvoiceItemRequest dto : request.getItems()) {

        InvoiceItem item;

        if (dto.getId() != null) {
            // Update existing item
            item = existingItems.remove(dto.getId());

            if (item == null) {
                throw new IllegalArgumentException("Item not found");
            }
        } else {
            // Create new item
            item = new InvoiceItem();
            invoice.addItem(item);
        }

        item.setProductName(dto.getProductName());
        item.setQuantity(dto.getQuantity());
        item.setPrice(dto.getPrice());

        total = total.add(
                dto.getPrice().multiply(BigDecimal.valueOf(dto.getQuantity()))
        );
    }

    // Remove items omitted from the request
    existingItems.values().forEach(invoice.getItems()::remove);

    invoice.setTotalAmount(total);
}
```

With `orphanRemoval = true`, any removed item is automatically deleted. This approach has several advantages:

- Existing items are updated with `UPDATE` statements instead of being deleted and recreated.
- New items are inserted with `INSERT`.
- Removed items are deleted automatically.
- Unchanged items are left untouched.

This is the approach you'll typically see in production applications because it preserves child IDs, reduces unnecessary SQL, and avoids breaking references from other tables.

---

# 3(More)

The previous code is good for learning JPA, but in a real project there are several things we'd improve.

---

# Production Architecture

A typical layered architecture looks like this:

```text
Controller
      │
      ▼
Request DTO
      │
      ▼
MapStruct
      │
      ▼
Service
      │
      ▼
Repository
      │
      ▼
Database

             ▲
             │
        Response DTO
             ▲
             │
         MapStruct
```

Notice something:

> **The service should not know about HTTP or JSON.**

The service works with domain objects and repositories. The controller deals with requests and responses.

---

# Project Structure

```text
controller/
    InvoiceController

dto/
    request/
        CreateInvoiceRequest
        UpdateInvoiceRequest
        InvoiceItemRequest

    response/
        InvoiceResponse
        InvoiceItemResponse

mapper/
    InvoiceMapper

entity/
    Invoice
    InvoiceItem

repository/
    InvoiceRepository

service/
    InvoiceService

exception/
    InvoiceNotFoundException

config/
```

This is much closer to what you'll find in production.

---

# Why Use MapStruct?

Without MapStruct:

```java
Invoice invoice = new Invoice();

invoice.setCustomerName(dto.getCustomerName());
invoice.setTotal(dto.getTotal());

...
```

Every service becomes filled with repetitive mapping code.

Imagine you have

- Customer
- Product
- Order
- Invoice
- Employee
- Warehouse

You'll write thousands of lines like

```java
entity.setX(dto.getX());
entity.setY(dto.getY());
entity.setZ(dto.getZ());
```

This is boring, error-prone, and hard to maintain.

---

With MapStruct

```java
Invoice invoice = mapper.toEntity(dto);
```

Done.

---

# Example DTO

```java
public class CreateInvoiceRequest {

    private String customerName;

    private List<InvoiceItemRequest> items;

}
```

---

# Entity

```java
@Entity
public class Invoice {

    @Id
    @GeneratedValue
    private Long id;

    private String customerName;

    private BigDecimal totalAmount;

    @OneToMany(...)
    private List<InvoiceItem> items;

}
```

---

# MapStruct Mapper

```java
@Mapper(componentModel = "spring")
public interface InvoiceMapper {

    Invoice toEntity(CreateInvoiceRequest dto);

    InvoiceResponse toResponse(Invoice invoice);

    InvoiceItem toEntity(InvoiceItemRequest dto);

    InvoiceItemResponse toResponse(InvoiceItem item);

    List<InvoiceItemResponse> toResponse(List<InvoiceItem> items);

}
```

No implementation.

MapStruct generates it during compilation.

---

Then

```java
@Service
@RequiredArgsConstructor
public class InvoiceService {

    private final InvoiceRepository repository;
    private final InvoiceMapper mapper;

    @Transactional
    public InvoiceResponse create(CreateInvoiceRequest request){

        Invoice invoice = mapper.toEntity(request);

        invoice.getItems()
               .forEach(item -> item.setInvoice(invoice));

        calculateTotal(invoice);

        repository.save(invoice);

        return mapper.toResponse(invoice);

    }

}
```

Very clean.

---

# Wait...

There is still this

```java
invoice.getItems()
       .forEach(item -> item.setInvoice(invoice));
```

Can MapStruct do this?

Yes.

---

## AfterMapping

```java
@Mapper(componentModel = "spring")
public interface InvoiceMapper {

    Invoice toEntity(CreateInvoiceRequest dto);

    @AfterMapping
    default void linkChildren(
            @MappingTarget Invoice invoice){

        invoice.getItems()
               .forEach(item -> item.setInvoice(invoice));

    }

}
```

Now service becomes

```java
Invoice invoice = mapper.toEntity(dto);

repository.save(invoice);
```

Even cleaner.

---

# Updating with MapStruct

Most beginners do

```java
Invoice invoice = mapper.toEntity(updateDto);

repository.save(invoice);
```

Don't do this.

This is one of the biggest mistakes.

Why?

Because you've created a **new detached entity**.

You lose

- Persistence Context
- Dirty Checking
- Lazy Collections
- Existing children
- Optimistic Lock version

Instead

```java
Invoice invoice = repository.findById(id)
        .orElseThrow();
```

Now invoice is Managed.

Then

```java
mapper.updateInvoice(updateDto, invoice);
```

Notice

**existing object**

not

**new object**

---

MapStruct

```java
@Mapper(componentModel = "spring")
public interface InvoiceMapper {

    void updateInvoice(
            UpdateInvoiceRequest dto,
            @MappingTarget Invoice invoice);

}
```

Generated code

```java
invoice.setCustomerName(dto.getCustomerName());

invoice.setDate(dto.getDate());

...
```

Only updates fields.

No new object.

This is exactly what we want.

---

# Ignore IDs

Production applications almost always ignore IDs during mapping.

```java
@Mapper(componentModel = "spring")
public interface InvoiceMapper {

    @Mapping(target="id",ignore=true)
    Invoice toEntity(CreateInvoiceRequest dto);

}
```

Otherwise

someone could send

```json
{
  "id": 100
}
```

You don't want that.

---

# Ignore Calculated Fields

Suppose

```java
Invoice

id

customerName

totalAmount
```

Total is calculated.

Never trust client.

Ignore it.

```java
@Mapping(target="totalAmount",ignore=true)
```

Then

```java
calculateTotal(invoice);
```

---

# Production Update

Instead of deleting all children

```java
invoice.getItems().clear();
```

A production application usually

```
Load Invoice

↓

Map existing items by ID

↓

Update existing

↓

Insert new

↓

Delete removed
```

Exactly like Git.

```
Old

A

B

C

New

A

B(updated)

D
```

Result

```
UPDATE B

INSERT D

DELETE C
```

Instead of

```
DELETE A

DELETE B

DELETE C

INSERT A

INSERT B

INSERT D
```

Huge performance improvement.

---

# Validation

Controller

```java
@PostMapping
public InvoiceResponse create(
        @Valid
        @RequestBody CreateInvoiceRequest dto){

    return service.create(dto);

}
```

DTO

```java
public class CreateInvoiceRequest {

    @NotBlank
    private String customerName;

    @NotEmpty
    private List<InvoiceItemRequest> items;

}
```

Item

```java
public class InvoiceItemRequest {

    @NotBlank
    private String productName;

    @Positive
    private Integer quantity;

    @Positive
    private BigDecimal price;

}
```

Never validate inside service.

Validation belongs to the API boundary.

---

# Exceptions

Instead of

```java
throw new RuntimeException();
```

Create

```java
public class InvoiceNotFoundException
        extends RuntimeException{
}
```

Then

```java
@ControllerAdvice
```

returns

```json
{
  "message": "Invoice not found",
  "status": 404,
  "timestamp": "..."
}
```

---

# Production Service

Notice how little code is left.

```java
@Transactional
public InvoiceResponse create(CreateInvoiceRequest dto){

    Invoice invoice = mapper.toEntity(dto);

    calculateTotal(invoice);

    repository.save(invoice);

    return mapper.toResponse(invoice);

}
```

This is close to what you'll see in many enterprise Spring Boot applications.

## Some additional production considerations

As applications grow, teams often add a few more patterns:

- **Separate request and response DTOs.** Request DTOs model what clients are allowed to send; response DTOs model what you want to expose. This prevents accidentally exposing internal fields such as `version`, `createdAt`, or database IDs.
- **Audit fields.** A common base entity contains `createdAt`, `updatedAt`, `createdBy`, and `lastModifiedBy`, populated automatically with Spring Data JPA auditing.
- **Optimistic locking.** Add an `@Version` field to entities like `Invoice` to prevent users from overwriting each other's changes.
- **Soft deletes.** Instead of physically deleting an invoice, many business systems mark it as deleted (`deleted = true` or `deletedAt`) for auditing and recovery.
- **Pagination and projections.** Listing invoices usually returns lightweight DTOs rather than full entities with all items loaded.
- **Avoid exposing entities directly.** Returning JPA entities from controllers can lead to lazy-loading exceptions, circular references, and leaking internal implementation details.
- **Transactional boundaries.** Controllers should typically not be `@Transactional`; transactions belong in the service layer where business logic executes.
- **Fetch strategies.** Keep associations `LAZY` by default and use `JOIN FETCH`, entity graphs, or dedicated queries when related data is actually needed.

---

## A note about MapStruct

MapStruct excels at **simple, deterministic mapping**:

- DTO ↔ Entity
- Entity → Response DTO
- Updating scalar fields with `@MappingTarget`

It's generally **not** the right place for business rules such as:

- Calculating invoice totals
- Validating stock availability
- Applying discounts
- Persisting entities
- Calling external services

A good rule of thumb is:

- **MapStruct:** "How do I copy data from one object to another?"
- **Service:** "What business decisions should be made?"
- **Repository:** "How is the data stored and retrieved?"

Keeping those responsibilities separate makes the codebase easier to test, maintain, and evolve as the application grows.
