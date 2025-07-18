# Validation

## Bean Validation with Hibernate

Java Bean Validatino: validate api request before transform the request to RequestBody Object, in controller. Failing validations cause bad request in response.

Dependency:

```xml
spring-boot-starter-validation
```

application.properties:

```
server.error.include-message=always
# it shows all details that is needed:
server.error.include-binding-errors=always
```

Anotations:

```java
# in request function:
@Valid

# in Java Class:
@NotBlank(message="Product name is required")
@Min(value=1, message="Price can not be lower than one")
@Max(value=5, message="Quantity can not be larger than 5")
```

## Aggregate Validation (to check the state)

```java
    @CommandHandler
    public ProductAggregate(CreateProductCommand cmd) {
        if(cmd.getName()==null){
            throw new IllegalArgumentException("Name cannot be null");
        }
        if(cmd.getQuantity()<=0){
            throw new IllegalArgumentException("Quantity cannot be less than 0");
        }
        if(cmd.getPrice()==null){
            throw new IllegalArgumentException("Price cannot be null");
        }

        AggregateLifecycle.apply(new ProductCreatedEvent(
                cmd.getProductId(),
                cmd.getName(),
                cmd.getPrice(),
                cmd.getQuantity(),
                cmd.getDescription()));
    }
```

## Message Dispatch Interceptor

- Define interceptor for the command (for example CreateProductCommand)

```java
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

@Component
public class CreateProductCommandInterceptor implements MessageDispatchInterceptor<CommandMessage<?>> {

    private static final Logger LOGGER= LoggerFactory.getLogger(CreateProductCommandInterceptor.class);

    @Nonnull
    @Override
    public BiFunction<Integer, CommandMessage<?>, CommandMessage<?>> handle(@Nonnull List<? extends CommandMessage<?>> messages) {
        return (index, command)->{
            LOGGER.info("Command Type: {}", command.getPayloadType());

            if( CreateProductCommand.class.equals(command.getPayloadType())) {
                CreateProductCommand cmd = (CreateProductCommand) command.getPayload();
                if(cmd.getName().isBlank()){
                    throw new IllegalArgumentException("Name cannot be blank");
                }
                if(cmd.getQuantity()<=0){
                    throw new IllegalArgumentException("Quantity cannot be negative");
                }
            }
            return command;
        };
    }
}
```

- Define configuration class to register the interceptor class

```java
@Configuration
public class AxonConfig {
    @Autowired
    public void registerCreateProductCommandInterceptor(ApplicationContext context, CommandBus commandBus){
        commandBus.registerDispatchInterceptor(
          context.getBean(CreateProductCommandInterceptor.class)
        );
    }
}
```

## Add ProductLookupTable to check if product exists or not

```java
@Entity
@Table(name = "productLookup")
public class ProductLookupEntity {
    @Id
    private String productId;
    @Column(unique=true)
    private String name;
    // getters and setters
}
```

```java
public interface ProductLookupRepository extends JpaRepository<ProductLookupEntity, String > {
    ProductLookupEntity findByProductIdOrName(String productId, String name);
}
```

```java
@Component
@ProcessingGroup("product-group")
public class ProductLookupProjection {
    private final ProductLookupRepository repository;
    public ProductLookupProjection(final ProductLookupRepository repository) {
        this.repository = repository;
    }
    @EventHandler
    public void on(ProductCreatedEvent event){
        ProductLookupEntity entity = new ProductLookupEntity(
                event.getProductId(),
                event.getName());
        repository.save(entity);
    }
}
```

in application.properties add this line:

```
axon.eventhandling.processors.product-group.mode=subscribing
```

and finaly inside command interceptor, check if product exists then throw an exception:

```java
@Component
public class CreateProductCommandInterceptor implements MessageDispatchInterceptor<CommandMessage<?>> {
    ... ProductLookupRepository productLookupRepository;

    @Nonnull
    @Override
    public BiFunction<Integer, CommandMessage<?>, CommandMessage<?>> handle(@Nonnull List<? extends CommandMessage<?>> messages) {
        return (index, command)->{
            if( CreateProductCommand.class.equals(command.getPayloadType())) {
                CreateProductCommand cmd = (CreateProductCommand) command.getPayload();

                ProductLookupEntity product=productLookupRepository.findByProductIdOrName(cmd.getProductId(), cmd.getName());

                if(product!=null){
                    throw new IllegalStateException(String.format("Product already exists, with id:%s or name:%s", cmd.getProductId(), cmd.getName()));
                }

            }
            return command;
        };
    }
}
```

## ControllerAdvice

Centerize the error handling class: This class handles errors from Controller, MessageInterceptor and CommandHandler.

**Note**: Where error eccurs inside command handlers then instead of a normal Exception, **CommandExecutionException** with handle the error. (or inside @QueryHandler-> **QueryExecutionException**).

```java
public class ProductServiceErrorHandling {
    @ExceptionHandler(value = {IllegalStateException.class})
    public ResponseEntity<String> handleIllegalStateException(final IllegalStateException e) {
        return new ResponseEntity<>(e.getMessage(), new HttpHeaders(), HttpStatus.INTERNAL_SERVER_ERROR);
    }

    @ExceptionHandler(value={Exception.class})
    public ResponseEntity<ErrorMessage> handleException(final Exception e) {
        ErrorMessage error=new ErrorMessage(e);
        return new ResponseEntity<>(error, new HttpHeaders(), HttpStatus.INTERNAL_SERVER_ERROR);
    }

    @ExceptionHandler(value = {CommandExecutionException.class})
    public ResponseEntity<ErrorMessage> handleCommandExecutionException(final CommandExecutionException e) {
        ErrorMessage error=new ErrorMessage(e);
        return new ResponseEntity<>(error, new HttpHeaders(), HttpStatus.INTERNAL_SERVER_ERROR);
    }
}
```

where ErrorMessage is

```java
public class ErrorMessage {
    private Exception error;
    private LocalDateTime timestamp;
    private String message;
    public ErrorMessage(Exception error) {...}
    // getters and setters
}
```

## Event Processor

- **Tracking Event Processor**: pull their message from a source using a thread that it manages itself.
  (A different thread). It will processing the event using an incremental back-off period.
- **Subscribing Event Processor**: subscribing themself to the source of events and are invoked by the
  thread managed by the pulling mechanism. (Same thread). Bubble up the exception to the publishing
  component of the event source.

## Propagate Exception from Event Handlers

Propagating exception from event handlers into controllers, make rollback transation. In normal senario if exception occurs inside event handlers then it doesn't rollback transation. But if wen register ListenerInvocationErrorHandler then we satisfy full transation as below:

1. Inside Event handler(ProductProjection) we should throw Exception inside the ExceptionHandler or we should do **NOTHING** and should let the exception happens.

```java
...
import org.axonframework.eventhandling.EventHandler;
...
@ExceptionHandler(resultType = Exception.class)
    public void handle(Exception e) throws Exception {
        LOGGER.error("Handling error inside ProductProjection: {}",e.getMessage());
        throw new Exception(e);
    }
```

2. Implements ListenerInvocationErrorHandler: we can log the exception and then re-throw it.

```java
public class ProductServiceEventErrorHandling implements ListenerInvocationErrorHandler {
    @Override
    public void onError(@Nonnull Exception exception, @Nonnull EventMessage<?> event, @Nonnull EventMessageHandler eventHandler) throws Exception {
        throw exception;
    }
}
```

3. Inside main function or inside AxonConfig.java

```java
@Autowired
public void configure(EventProcessingConfigurer configurer){
    configurer.registerListenerInvocationErrorHandler("product-group",
            configuration -> new ProductServiceEventErrorHandling());
}
```

3. Or when we don't have implement ListenerInvocationErrorHandler like above we can use the below code which is the simplest code:

```java
@Autowired
public void configure(EventProcessingConfigurer configurer){
    configurer.registerListenerInvocationErrorHandler("product-group",
            configuration -> PropagatingErrorHandler.instance());
}
```

## Figure

![Validation](Validation.png)
