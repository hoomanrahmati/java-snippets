## <h1 style="color:white;">Axon Platform (Axon Server and Framework)</h1>

- [Sample](axon-sample.md)
- [Multi Aggregate Sample](axon-multi-aggregate.md)

Axon Framework is a java framework that is used to simplify the building of event-driven microservices that are based on CQRS, Event-Sourcing and Domain-Driven Design. (without more config)

Axon Server duty is to manage Event-Bus and Event-Store.

Aggregate, Command, Event, Query

Controller -(CommandGateway)-> Aggregate -(EventSourcing)-> Projection -(Repository)-> Query Database

```dockerfile
docker run -d --name axon-server -p 8024:8024 -p 8124:8124 axoniq/axonserver
java -jar axonserver.jar
```

- [CommandController](#productcommandcontroller)
- [Aggregate](#productaggregate)
- [QueryController](#productquerycontroller)
- [Projection](#productprojection-producteventhandler)
- [Entity (View)](#productentity-productview)
- [Repository](#productrepository)
- [record](#record)
- [Error Handling](#error-handling)
- [Saga](#saga)
- [DeadlineManager](#deadlinemanager)
- [figure](#figure)

## <u>ProductCommandController</u>

- @RestController
- @RequestMapping
- @PostMapping
- @RequestBody

👻Dependencies:

- **CommandGateway** if wen don't use service

```java
@RestController
@RequestMapping("/products")
public class ProductCommandController{
  inject: CommandGateway commandGateway;

  @PostMapping
  public String createProduct(CreateProductRequest request){
    string id= UUID.randomUUID().toString();
    return commandGateway.sendAndWait(new CreateProductCommand(id, ...));
  }
}
```

## <u>ProductAggregate</u>

### Handle Commands (vs. Saga that handle Events)

Get **Commands**, validate Business Logic, keep **States** and return **Events**

consist of 1. **State**, 2. **Command Handler**, 3. **Business Logic** and 4. **Event Sourcing Handler**

- @Aggregate
- @AggregateIdentifier
- @CommandHandler
- @EventSourcingHandler

```java
@Aggregate
public class ProductAggregate{
  1.
  @AggregateIdentifier
  private String productId;
  private String name;
  private Integer count;

  protected ProductAggregate(){}

  2.
  @CommandHandler
  public ProductAggregate(CreateProductCommand command){
    3.
    if(command is not valid){
      throw new RuntimeException("invalid input!");
    }
    ProductCreatedEvent event= new ProductCreatedEvent(...command);
    AggregateLifecycle.apply(event);
  }

  4.
  @EventSourcingHandler
  public void on(ProductCreatedEvent event){
    productId=event.productId();
    name=event.name();
    count++;
  }
}
```

## ProductQueryController

- @RestController
- @RequestMapping
- @GetMapping
- @ParamVariable

**dependencies:**

- ProductRepository

```java
@RestController
@RequestMapping("/products")
public class ProductQueryController{
  ... ProductRepository repository;
  @GetMpping
  public List<ProductEntity> findAllProduct(){
    return repository.find();
  }

  @GetMapping("/{productId}")
  public ProductEntity findProductById(@ParamVariable("productId") String productId){
    return repository.findById(productId).orElseThrow(()->new RuntimeException("no product found!"));
  }
}
```

## ProductProjection (ProductEventHandler)

handle **Events** and then persist data into database

- @Service
- @EventHandler

**dependencies:**

- ProductRepository

```java
@Service
public class ProductProjection{
  ... ProductRepository repository;

  @EventHandler
  public void on(ProductCreatedEvent event){
    ProdoctEntity entity=new ProdoctEntity(...event);
    repository.save(entity);
  }
}
```

## ProductEntity (ProductView)

- @data
- @Entity
- @Id

```java
@Data
@Entity
public class ProductEntity{
  @Id
  private String productId;
  private String name;
  private Integer count;
}
```

## ProductRepository

to persist data

```
public interface ProductRepository extends JpaRepository<ProductEntity, String>{}
```

## record:

- CreateProductCommand:
  - **ProductAggregate**: to handle the command
  - **ProductCommandController**: to send then command
- ProductCreatedEvent
  - **ProductAggregate**: to handle in EventSourcingHandler
  - **ProductProjection**: to persist in to Query Database
- CreateProductRequest:
  - ProductCommandController: get request body

for a command sample

```java
public class CreateOrderCommand {
    @TargetAggregateIdentifier
    private final String orderId;
    private final String product;

    public CreateOrderCommand(String orderId, String product) {
        this.orderId = orderId;
        this.product = product;
    }

    // getters
}
```

Another sample from Copilot

```java

public class FindAllOrdersQuery {}

------------------Prodjection-----------------
@Component
public class OrderProjection {
    private final Map<String, String> orders = new ConcurrentHashMap<>();

    @EventHandler
    public void on(OrderCreatedEvent event) {
        orders.put(event.getOrderId(), event.getProduct());
    }

    @QueryHandler
    public List<String> handle(FindAllOrdersQuery query) {
        return new ArrayList<>(orders.values());
    }
}

------------------Controller------------------
@RestController
@RequestMapping("/orders")
public class OrderController {

    private final CommandGateway commandGateway;
    private final QueryGateway queryGateway;

    public OrderController(CommandGateway commandGateway, QueryGateway queryGateway) {
        this.commandGateway = commandGateway;
        this.queryGateway = queryGateway;
    }

    @PostMapping
    public CompletableFuture<String> createOrder(@RequestParam String product) {
        String orderId = UUID.randomUUID().toString();
        return commandGateway.send(new CreateOrderCommand(orderId, product));
    }

    @GetMapping
    public CompletableFuture<List<String>> getOrders() {
        return queryGateway.query(new FindAllOrdersQuery(),
                ResponseTypes.multipleInstancesOf(String.class));
    }
}

```

## Error Handling:

Using in CommandHandler

```java
@CommandHandler
public void handle(CreateOrderCommand cmd) {
    if (cmd.getQuantity() <= 0) {
        throw new IllegalArgumentException("Quantity must be greater than zero");
    }
    // Apply event
}
```

```java
@Configuration
public class AxonConfig {

    @Autowired
    public void configure(EventProcessingConfigurer configurer) {
        configurer.registerListenerInvocationErrorHandler(
            "orderProcessor",
            configuration -> new CustomListenerInvocationErrorHandler()
        );
    }
}

@ProcessingGroup("orderProcessor")
@Component
public class OrderEventHandler {

    @EventHandler
    public void on(OrderCreatedEvent event) {
        // Simulate an error
        throw new RuntimeException("Oops! Something went wrong.");
    }
}
```

## Saga:

### Handle Events (vs. Aggregate that handles Commands)

- @Saga
- @StartSaga
- @SagaEventHandler(assosiationProperty = "orderId")
- @EndSaga
- @Autowired

Dependencies:

- CommandGateway

important points:

- when start saga then make the association:

```java
SagaLifecycle.associateWith("orderId", event.getOrderId());
```

- if failed or end then:

```java
SagaLifecycle.end();
```

saga manage the flow

```java
@Saga
public class OrderManagementSaga {

    // because sagas are serialized so none-serializable field (like CommandGateway) as transient
    @Autowired
    private transient CommandGateway commandGateway;

    @StartSaga
    @SagaEventHandler(associationProperty = "orderId")
    public void on(OrderPlacedEvent event) {
        SagaLifecycle.associateWith("orderId", event.getOrderId());
        commandGateway.send(new ReserveInventoryCommand(event.getOrderId(), event.getProductId()));
    }

    @SagaEventHandler(associationProperty = "orderId")
    public void on(InventoryReservedEvent event) {
        commandGateway.send(new ProcessPaymentCommand(event.getOrderId(), event.getPaymentDetails()));
    }

    @SagaEventHandler(associationProperty = "orderId")
    public void on(PaymentFailedEvent event) {
        commandGateway.send(new CancelInventoryReservationCommand(event.getOrderId()));
        SagaLifecycle.end();
    }

    @EndSaga
    @SagaEventHandler(associationProperty = "orderId")
    public void on(OrderCompletedEvent event) {
        // Clean up or log success
    }
}
```

another sample of saga for hotel booking

```java
@Saga
public class HotelBookingSaga {

    @Autowired
    private transient CommandGateway commandGateway;

    @StartSaga
    @SagaEventHandler(associationProperty = "bookingId")
    public void on(BookingRequestedEvent event) {
        SagaLifecycle.associateWith("bookingId", event.getBookingId());
        commandGateway.send(new ReserveRoomCommand(event.getBookingId(), event.getRoomType()));
    }

    @SagaEventHandler(associationProperty = "bookingId")
    public void on(RoomReservedEvent event) {
        commandGateway.send(new ChargeCustomerCommand(event.getBookingId(), event.getCustomerId(), event.getAmount()));
    }

    @SagaEventHandler(associationProperty = "bookingId")
    public void on(PaymentConfirmedEvent event) {
        commandGateway.send(new SendConfirmationEmailCommand(event.getBookingId(), event.getCustomerEmail()));
        SagaLifecycle.end();
    }

    @SagaEventHandler(associationProperty = "bookingId")
    public void on(PaymentFailedEvent event) {
        commandGateway.send(new CancelRoomReservationCommand(event.getBookingId()));
        SagaLifecycle.end();
    }
}
```

when it fails to finish its job

```java
@Saga
public class OrderCompensationSaga {

    @Autowired
    private transient CommandGateway commandGateway;

    @StartSaga
    @SagaEventHandler(associationProperty = "orderId")
    public void on(OrderPlacedEvent event) {
        SagaLifecycle.associateWith("orderId", event.getOrderId());
        commandGateway.send(new ReserveInventoryCommand(event.getOrderId(), event.getProductId()));
    }

    @SagaEventHandler(associationProperty = "orderId")
    public void on(InventoryReservedEvent event) {
        commandGateway.send(new ChargePaymentCommand(event.getOrderId(), event.getPaymentDetails()));
    }

    @SagaEventHandler(associationProperty = "orderId")
    public void on(PaymentFailedEvent event) {
        // Compensation step
        commandGateway.send(new CancelInventoryReservationCommand(event.getOrderId()));
    }

    @SagaEventHandler(associationProperty = "orderId")
    public void on(InventoryCancellationConfirmedEvent event) {
        // Notify failure, log, or trigger fallback
        commandGateway.send(new NotifyCustomerCommand(event.getOrderId(), "Payment failed, order canceled."));
        SagaLifecycle.end();
    }

    @EndSaga
    @SagaEventHandler(associationProperty = "orderId")
    public void on(OrderCompletedEvent event) {
        // Successful flow
    }
}
```

## DeadlineManager

- private transient **DeadlineManager** deadlineManager;
- this.deadlineId = **deadlineManager.schedule**(Duration.ofMinutes(30),"payment-timeout");
- deadlineManager.**cancelSchedule**(deadlineId);
- @DeadlineHandler(deadlineName = "payment-timeout")

```java
@Saga
public class OrderProcessSage{

    ... commandGateway

    @Autowired
    private transient DeadlineManager deadlineManager;

    private String orderId;
    private String deadlineId;

    @StartSaga
    @SagaEventHandler(associationProperty = "orderId")
    public void handle(OrderCreatedEvent event) {
        this.orderId = event.getOrderId();
        this.deadlineId = deadlineManager.schedule(
            Duration.ofMinutes(30),
            "payment-timeout"
        );
        ...
    }

    @SagaEventHandler(associationProperty = "orderId")
    public void handle(OrderConfirmedEvent event) {
        deadlineManager.cancelSchedule(deadlineId);
        // Additional confirmation logic
        SagaLifecycle.end();
    }

    @SagaEventHandler(associationProperty = "orderId")
    @EndSaga
    public void handle(OrderFailedEvent event) {
        deadlineManager.cancelSchedule(deadlineId);
        ...
    }

    @DeadlineHandler(deadlineName = "payment-timeout")
    public void handlePaymentTimeout() {
        commandGateway.send(new CancelOrderCommand(orderId, "Payment timeout"));
        SagaLifecycle.end();
    }
}
```

## figure

![figure](Axon%20Server%20and%20Framework.png)
