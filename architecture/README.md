[back](../README.md)

[1](1.md)
[2](2.md)
[3](3.md)
[4](4.md)
[5](5.md)

For a real Spring Boot application, I would probably use something like:

```text
com.example.invoice
│
├── domain
│   ├── model
│   │   ├── Invoice.java
│   │   └── InvoiceItem.java
│   │
│   └── exception
│       └── InvoiceException.java
│
├── application
│   ├── port
│   │   ├── in
│   │   │   ├── CreateInvoiceUseCase.java
│   │   │   ├── UpdateInvoiceUseCase.java
│   │   │   └── DeleteInvoiceUseCase.java
│   │   │
│   │   └── out
│   │       └── InvoiceRepository.java
│   │
│   ├── command
│   │   ├── CreateInvoiceCommand.java
│   │   └── UpdateInvoiceCommand.java
│   │
│   └── service
│       └── InvoiceApplicationService.java
│
├── adapter
│   ├── in
│   │   └── web
│   │       ├── InvoiceController.java
│   │       ├── CreateInvoiceRequest.java
│   │       └── InvoiceResponse.java
│   │
│   └── out
│       └── persistence
│           ├── InvoiceJpaEntity.java
│           ├── InvoiceJpaRepository.java
│           └── InvoicePersistenceAdapter.java
│
└── InvoiceApplication.java
```

### Hexagonal layers per service

```text
domain/           # pure business model + domain services (no Spring)
application/
  port/in/        # use-case interfaces
  port/out/       # driven ports (repositories, event publisher)
  service/        # use-case implementations (transactional boundary)
adapter/
  in/web/         # REST controllers
  in/messaging/   # @KafkaListener -> calls in-port
  out/persistence/# JPA repositories implementing out-ports
  out/messaging/  # KafkaTemplate implementing EventPublisherPort
config/           # Spring wiring
```

### Sales Service (folder structure)

```text
sales-service/src/main/java/com/example/sales/
├── SalesApplication.java
├── domain/
│   ├── model/
│   │   ├── Order.java
│   │   ├── OrderLine.java
│   │   ├── OrderStatus.java
│   │   ├── Customer.java
│   │   └── OrderId.java
│   └── event/
│       └── OrderPlacedDomainEvent.java
├── application/
│   ├── port/
│   │   ├── in/PlaceOrderUseCase.java
│   │   ├── in/CancelOrderUseCase.java
│   │   ├── out/OrderRepositoryPort.java
│   │   ├── out/CustomerRepositoryPort.java
│   │   └── out/EventPublisherPort.java
│   └── service/OrderApplicationService.java
├── adapter/
│   ├── in/
│   │   ├── web/OrderController.java
│   │   ├── web/dto/PlaceOrderRequest.java
│   │   └── messaging/BillingEventsListener.java
│   │   └── messaging/CompensationListener.java
│   └── out/
│       ├── persistence/
│       │   ├── OrderJpaEntity.java
│       │   ├── OrderJpaRepository.java
│       │   ├── OrderPersistenceAdapter.java
│       │   └── CustomerPersistenceAdapter.java
│       └── messaging/KafkaEventPublisherAdapter.java
├── config/KafkaProducerConfig.java
└── config/SalesConfig.java
```

### Billing Service

```text
billing-service/src/main/java/com/example/billing/
├── BillingApplication.java
├── domain/model/{Invoice, Payment, InvoiceStatus}.java
├── application/
│   ├── port/in/CreateInvoiceUseCase.java
│   ├── port/out/{InvoiceRepositoryPort,PaymentGatewayPort,EventPublisherPort}.java
│   └── service/InvoiceApplicationService.java
├── adapter/
│   ├── in/messaging/OrderEventsListener.java   # consumes OrderPlaced
│   └── out/{persistence,messaging,payment}
└── config/BillingConfig.java
```

### Inventory Service

```text
inventory-service/src/main/java/com/example/inventory/
├── InventoryApplication.java
├── domain/model/{Product, StockItem}.java
├── application/
│   ├── port/in/ReserveStockUseCase.java
│   ├── port/in/ReleaseStockUseCase.java
│   ├── port/out/{StockRepositoryPort,EventPublisherPort}.java
│   └── service/StockApplicationService.java
├── adapter/
│   ├── in/messaging/OrderEventsListener.java
│   └── out/{persistence,messaging}
└── config/InventoryConfig.java
```
