# Validation

## Bean Validation with Hibernate

Java Bean Validatino: validate api request before transform the request to RequestBody Object, in controller. And if validation fails then it send back bad request in response.

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

## Figure

![Validation](Validation.png)
